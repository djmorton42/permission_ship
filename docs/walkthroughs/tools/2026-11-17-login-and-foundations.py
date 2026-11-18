"""Content of ../2026-11-17-login-and-foundations.html. Build: python3 2026-11-17-login-and-foundations.py"""

from pathlib import Path

from walkthrough import Walkthrough

w = Walkthrough(
    commit="1d1b10b",
    title="Permishly Login Walkthrough",
    header="""
  <header class="intro">
    <span class="eyebrow">Code walkthrough</span>
    <h1>How school administrator login works</h1>
    <p class="lede">What the first Permishly feature added, layer by layer, and why each part is there: row-level security, database roles, commands and queries, the session API, and the React screens.</p>
    <div class="meta"><span>Commit <b>1d1b10b</b></span><span><b>64</b> files</span><span><b>34</b> backend specs · <b>6</b> frontend tests</span></div>
  </header>""".strip("\n"),
)
code, raw, section = w.code, w.raw, w.section

B = "backend/"
F = "frontend/"


# ---------------------------------------------------------------- 0
section("overview", "0", "What we built", f"""
<p>A school administrator can open Permishly, log in with an email and password, and see their school board and the schools they run. The boards and schools are demo data that the seeds load. There is no screen to create them yet.</p>
<p>Most of the code is not the login form. Permishly is multi-tenant: one installation serves many school boards, and data from one board must never reach another. <code>architecture.md</code> says this must be in place before the first table that holds board data. The users table is such a table, so login had to be built on top of that foundation.</p>
<p>The walkthrough follows the layers in the order a request passes through them, from the database up to React. Each part says what the code does and why it is there.</p>

<h3>The request path for login</h3>
<pre class="mermaid">
sequenceDiagram
  participant B as Browser (React)
  participant C as SessionsController
  participant L as Authentication::LogIn
  participant D as Postgres
  B->>C: POST /api/v1/session {{email, password}}
  C->>L: call(email, password, ip, user agent)
  L->>D: find identity, check password
  L->>D: identity_organization_ids(identity)
  L->>D: INSERT session (organization if only one)
  L-->>C: success(session_id)
  C-->>B: 204 + signed session cookie
  B->>C: GET /api/v1/session
  C->>D: CurrentSessionQuery → CurrentUserQuery (tenant set)
  C-->>B: signed_in, or organization_required
</pre>

<h3>The parts</h3>
<div class="table"><table>
<thead><tr><th>Layer</th><th>Files</th><th>Job</th></tr></thead>
<tbody>
<tr><td>Tables</td><td><code>db/migrate/*</code>, <code>app/models/*</code></td><td>Organizations, identities, schools, users, school administrators, sessions</td></tr>
<tr><td>Tenant isolation</td><td><code>lib/tenant_tables.rb</code>, <code>lib/tenancy.rb</code></td><td>Row-level security policies, and the helper that sets the current board</td></tr>
<tr><td>Database roles</td><td><code>config/database.yml</code>, <code>db/privileges.sql</code>, <code>lib/tasks/database_privileges.rake</code></td><td>The app connects as a role that the policies apply to</td></tr>
<tr><td>Base classes</td><td><code>app/lib/use_case*.rb</code>, <code>app/capabilities/application_*.rb</code></td><td>Commands (writes) and queries (reads), with results instead of exceptions</td></tr>
<tr><td>Login logic</td><td><code>app/capabilities/authentication/*</code>, <code>accounts/*</code></td><td>Log in, pick a board, log out, read the current session</td></tr>
<tr><td>HTTP</td><td><code>app/controllers/api/v1/*</code>, <code>concerns/session_cookie.rb</code></td><td>Map results to status codes, set the cookie, rate limit</td></tr>
<tr><td>React</td><td><code>frontend/src/features/authentication/*</code>, <code>pages/HomePage.tsx</code></td><td>Login form, board picker, signed-in page, log out</td></tr>
<tr><td>Demo data</td><td><code>db/seeds/demo.rb</code></td><td>Three boards, nine schools, ten administrator accounts</td></tr>
</tbody></table></div>
<p class="aside">All paths below start in the repo root. Backend paths start with <code>backend/</code>. The code is quoted from commit <code>{w.commit}</code>.</p>
""")

# ---------------------------------------------------------------- 1
section("tables", "1", "The tables", f"""
<p>Two kinds of table exist. A <strong>global</strong> table has no board column and is shared by the whole installation. A <strong>tenant</strong> table has an <code>organization_id</code> column, and each row belongs to one board.</p>
<div class="table"><table>
<thead><tr><th>Table</th><th>Kind</th><th>Holds</th></tr></thead>
<tbody>
<tr><td><code>organizations</code></td><td>Global</td><td>A school board (or an independent school). This is the tenant.</td></tr>
<tr><td><code>identities</code></td><td>Global</td><td>Email and password digest. One per person.</td></tr>
<tr><td><code>sessions</code></td><td>Global</td><td>A login. The identity, and the board picked (null until picked).</td></tr>
<tr><td><code>schools</code></td><td>Tenant</td><td>Name and IANA time zone.</td></tr>
<tr><td><code>users</code></td><td>Tenant</td><td>The person inside one board: name, and the identity they log in with.</td></tr>
<tr><td><code>school_administrators</code></td><td>Tenant</td><td>Which user runs which school.</td></tr>
</tbody></table></div>
<p>Why split <code>identities</code> from <code>users</code>? A person can work in two boards. They should have one password, but two separate sets of data and roles. So the password lives once, globally, and each board has its own user row that points to the identity.</p>
{code(B+"db/migrate/20261117000004_create_users.rb", "ruby")}
<p>The unique index on <code>(organization_id, identity_id)</code> means a person has at most one user in each board. The index on <code>identity_id</code> alone serves the login lookup in part 5.</p>
<p>Every table uses a UUIDv7 primary key from Postgres's <code>uuidv7()</code>. Nobody can guess the next ID, and the IDs still sort by creation time.</p>
{code(B+"db/migrate/20261117000002_create_identities.rb", "ruby", note="The check constraint backs up the model's <code>normalizes :email</code>: the database refuses an email with capitals even if some code skips the model.")}
""")

# ---------------------------------------------------------------- 2
section("rls", "2", "Row-level security", f"""
<p>Postgres row-level security (RLS) lets a table carry a filter that the database applies to every query. We use it so that a query that forgets <code>WHERE organization_id = …</code> still cannot see another board's rows.</p>
<p>Every tenant table is created with one helper, so no table can be made without the policy:</p>
{code(B+"lib/tenant_tables.rb", "ruby")}
<p>What each part is for:</p>
<ul>
<li><strong><code>ENABLE</code> and <code>FORCE ROW LEVEL SECURITY</code>.</strong> Enable turns the policy on. Force applies it to the table owner too. Without force, the owner sees all rows.</li>
<li><strong>The policy.</strong> A row is visible, and writable, only when its <code>organization_id</code> equals the session setting <code>app.organization_id</code>. The policy has no separate <code>WITH CHECK</code>, so Postgres uses the same rule for inserts and updates. You cannot write a row for another board.</li>
<li><strong><code>NULLIF(…, '')</code>.</strong> After a transaction that set the value ends, Postgres returns an empty string for it, not null. <code>''::uuid</code> raises an error. With <code>NULLIF</code> the comparison is against null, so no rows match. The rule is: <em>no board set means no rows</em>.</li>
<li><strong>The <code>(organization_id, id)</code> unique index</strong> lets other tenant tables point at a row by board and ID together.</li>
<li><strong><code>add_tenant_reference</code></strong> makes a composite foreign key on <code>(organization_id, school_id)</code>. A school administrator row in board A cannot point to a school in board B, because the pair (A, school-in-B) does not exist.</li>
</ul>
{code(B+"db/migrate/20261117000005_create_school_administrators.rb", "ruby")}
<p>The schema file is <code>db/structure.sql</code>, not <code>schema.rb</code>, because <code>schema.rb</code> cannot store policies. <code>config/application.rb</code> sets this, and also turns on <code>strict_loading_by_default</code>, so associations must be loaded explicitly and N+1 queries raise errors:</p>
{code(B+"config/application.rb", "ruby", "Login uses a signed session cookie", "strict_loading_by_default = true")}
""")

# ---------------------------------------------------------------- 3
section("roles", "3", "Database roles", f"""
<p>RLS has one large hole: a superuser, or any role with <code>BYPASSRLS</code>, ignores every policy. The Docker Postgres user <code>permishly</code> is a superuser. If the app connected as that user, all the policies above would do nothing.</p>
<p>So there are three roles:</p>
<div class="table"><table>
<thead><tr><th>Role</th><th>Used by</th><th>RLS</th></tr></thead>
<tbody>
<tr><td><code>permishly</code> (owner)</td><td>Migrations, schema loads, seeds</td><td>Bypasses</td></tr>
<tr><td><code>permishly_app</code></td><td>The running app, job workers, and the specs</td><td>Applies</td></tr>
<tr><td><code>permishly_cross_tenant_reader</code></td><td>Owns the one function that reads across boards (part 5). Cannot log in.</td><td>Bypasses</td></tr>
</tbody></table></div>
<p><code>config/database.yml</code> has two configs for each database. Rails connects the app to <code>primary</code>, the app role. <code>database_tasks: false</code> tells Rails not to run migrations through it. The <code>owner</code> config is the one migrations use.</p>
{code(B+"config/database.yml", "yaml", "default: &default", "seeds: true", note="<code>seeds: true</code> is needed because Rails only seeds the <code>primary</code> config by default, and <code>primary</code> no longer runs database tasks.")}
<p>The app role needs <code>GRANT</code>s on every table. Rails writes <code>structure.sql</code> with <code>pg_dump --no-privileges --no-owner</code>, and those flags are hard-coded. Grants put in a migration would be lost the next time someone loads the schema. So the grants live in their own file, written so that it is safe to run again and again:</p>
{code(B+"db/privileges.sql", "sql")}
<p>A rake file applies it after every task that changes the schema. It also fixes a trap: some Rails tasks, for example <code>db:migrate:redo</code>, use the default <code>ActiveRecord::Base</code> connection, which is now the app role. The app role cannot change the schema, so the first block below points all <code>db:</code> tasks at the owner.</p>
{code(B+"lib/tasks/database_privileges.rake", "ruby")}
""")

# ---------------------------------------------------------------- 4
section("tenancy", "4", "Setting the current board", f"""
<p>The policy reads <code>app.organization_id</code>. Something has to set it. <code>Tenancy.with_organization</code> sets it for one block of code:</p>
{code(B+"lib/tenancy.rb", "ruby")}
<ul>
<li><strong><code>set_config(…, true)</code></strong> is the function form of <code>SET LOCAL</code>. The value lasts only until the transaction ends. That is why the block runs inside a transaction.</li>
<li><strong>Restore on exit.</strong> Rails joins nested transactions into one. If a block for board A ran inside a longer transaction, the setting would stay after the block ended. The <code>ensure</code> puts the previous value back. Specs depend on this: the whole spec runs in one transaction, so without the restore, a board set in a spec's setup would still be set during the request under test.</li>
<li><strong>The <code>rescue</code> in <code>restore</code>.</strong> After a database error, Postgres rejects every statement until rollback. Restoring would raise a second error and hide the first. The rollback drops the setting anyway, so we skip it in that one case.</li>
</ul>
<p>The spec that proves all this runs as the app role. Its first example checks that, because a spec that ran as a superuser would pass whatever the policy said:</p>
{code(B+"spec/tenancy/row_level_security_spec.rb", "ruby", "it \"runs specs as a role", "it \"restores the outer organization", extra=-2, note="The other examples check that rows of another board cannot be referenced or inserted. I wrote them before the policy existed and watched five fail because both boards' rows were visible.")}
""")

# ---------------------------------------------------------------- 5
section("lookup", "5", "The one read across boards", f"""
<p>Login has a problem. Before the person is logged in, no board is set, so RLS hides every user row. But to log in we must find which boards this identity has users in.</p>
<p><code>architecture.md</code> says to solve this with a narrow database function, not by giving the app a role that bypasses RLS:</p>
{code(B+"db/migrate/20261117000007_create_identity_organization_ids.rb", "ruby")}
<ul>
<li><strong><code>SECURITY DEFINER</code></strong> runs the function with its owner's rights. <code>db/privileges.sql</code> makes <code>permishly_cross_tenant_reader</code> the owner. That role has <code>BYPASSRLS</code>, but it can read only two columns of <code>users</code>, and nobody can log in as it.</li>
<li><strong>It returns board IDs only</strong>, not names or user data. The caller reads names from <code>organizations</code>, which is global anyway.</li>
<li><strong><code>SET search_path</code></strong> stops a caller from creating a look-alike <code>users</code> table in another schema to trick the function.</li>
<li>Only <code>permishly_app</code> can run it. <code>PUBLIC</code> loses <code>EXECUTE</code>.</li>
</ul>
<p>The Ruby side is one method on <code>Identity</code>:</p>
{code(B+"app/models/identity.rb", "ruby")}
""")

# ---------------------------------------------------------------- 6
section("base", "6", "Commands, queries and results", f"""
<p>The architecture uses commands for writes and queries for reads. A controller never touches models directly. It calls a command or query and gets back a <code>UseCaseResult</code>: a success with a value, or a failure with a category and a list of errors.</p>
{code(B+"app/lib/use_case_result.rb", "ruby")}
<p>The category decides the HTTP status (part 8). <code>unauthenticated</code> was added for this feature: 401, for "not logged in" and "login failed".</p>
<p>Commands and queries share one shape, held in a concern:</p>
{code(B+"app/lib/use_case.rb", "ruby")}
<ul>
<li><strong>Inputs are ActiveModel attributes.</strong> They are typed, and <code>validates</code> works on them.</li>
<li><strong>Every use case has an <code>organization_id</code> input, required by default.</strong> A class that does global work, such as login, opts out with <code>runs_without_organization</code>. The default is the safe one: forgetting the declaration gives a validation failure, not unscoped access.</li>
<li><strong><code>call</code> splits its keywords.</strong> The architecture shows both <code>call(inputs, fake: x)</code> and <code>RosterQuery.call(school_id:, page:)</code>. Keywords that name a declared <code>dependency</code> are dependencies, and the rest are inputs.</li>
<li><strong>The ActiveModel modules are included at module level</strong>, not inside <code>included do</code>. If they were in that block, their <code>initialize</code> would come first in Ruby's lookup order and hide ours. That was the first bug the specs found.</li>
</ul>
<p>A command validates, opens a transaction, sets the board, runs <code>perform</code>, and rolls back if <code>perform</code> returns a failure:</p>
{code(B+"app/capabilities/application_command.rb", "ruby")}
<p>A query runs in a read-only transaction and blocks writes in Active Record too:</p>
{code(B+"app/capabilities/application_query.rb", "ruby")}
<p>Two details here came from bugs:</p>
<ul>
<li><strong><code>read_only</code> is computed before <code>transaction</code> opens.</strong> The first version checked it inside the block, where a transaction is always open, so no query was ever read-only. The specs could not see this, because every spec runs inside a transaction. A spec with <code>use_transactional_tests = false</code> now checks <code>SHOW transaction_read_only</code> returns <code>on</code>.</li>
<li><strong><code>ActiveRecord::Base.while_preventing_writes</code>, not <code>ApplicationRecord</code>.</strong> The connection pool belongs to <code>ActiveRecord::Base</code>. Called on <code>ApplicationRecord</code>, the guard did nothing.</li>
</ul>
""")

# ---------------------------------------------------------------- 7
section("auth", "7", "The login logic", f"""
<p>The Authentication capability owns identities and sessions. Its code is in <code>app/capabilities/authentication/</code>.</p>
<h3>Log in</h3>
{code(B+"app/capabilities/authentication/log_in.rb", "ruby")}
<ul>
<li><strong><code>authenticate_by</code></strong> (Rails 7.1+) takes the same time when the email is unknown as when the password is wrong. Otherwise an attacker could time the response to learn which emails have accounts.</li>
<li><strong>One message for both cases</strong>, for the same reason.</li>
<li><strong>One board: the session is in it at once. More than one: <code>organization_id</code> stays null</strong> and the person picks. Login never lists boards before the password is correct, because that would tell anyone which boards an email belongs to.</li>
<li>It returns only the session ID. The controller puts that in the cookie.</li>
</ul>
<h3>Pick a board</h3>
{code(B+"app/capabilities/authentication/choose_organization.rb", "ruby", note="The membership check uses the same database function as login. Without it, a logged-in person could send any board's ID and read that board's data.")}
<h3>Read the current session</h3>
<p><code>GET /api/v1/session</code> answers one of three ways: not logged in, logged in but needs to pick a board, or signed in.</p>
{code(B+"app/capabilities/authentication/current_session_query.rb", "ruby")}
<p>When a board is set, it calls a query from the Accounts capability. This query is tenant-scoped, so RLS does the filtering:</p>
{code(B+"app/capabilities/accounts/current_user_query.rb", "ruby", note="<code>User.find_by(identity_id:)</code> has no board filter in Ruby. Row-level security supplies it. The spec for this query gives one identity users in two boards with different names, so a broken policy would return the wrong name.")}
<p>The <code>Data.define</code> classes are the response DTOs. They define <code>as_json</code>, so the API's JSON shape is written down in one place and is never an Active Record model.</p>
""")

# ---------------------------------------------------------------- 8
section("http", "8", "The HTTP layer", f"""
<p>The routes:</p>
{raw('''resource :session, only: %i[show create destroy] do
  resource :organization, only: :create, controller: "session_organizations"
end''', "ruby", "backend/config/routes.rb · excerpt")}
<div class="table"><table>
<thead><tr><th>Request</th><th>Does</th><th>Answers</th></tr></thead>
<tbody>
<tr><td><code>POST /api/v1/session</code></td><td>Log in</td><td>204 and cookie, or 401</td></tr>
<tr><td><code>GET /api/v1/session</code></td><td>Current session</td><td>200 <code>signed_in</code> or <code>organization_required</code>, or 401</td></tr>
<tr><td><code>POST /api/v1/session/organization</code></td><td>Pick a board</td><td>204, 401 or 403</td></tr>
<tr><td><code>DELETE /api/v1/session</code></td><td>Log out</td><td>204</td></tr>
</tbody></table></div>
<p>The base controller turns a result into a response, using the table from <code>architecture.md</code>:</p>
{code(B+"app/controllers/api/v1/base_controller.rb", "ruby")}
<p>The cookie. The app is API-only, so <code>config/application.rb</code> adds the cookie middleware back, and the base controller includes <code>ActionController::Cookies</code>.</p>
{code(B+"app/controllers/concerns/session_cookie.rb", "ruby")}
<ul>
<li><strong>Signed:</strong> the browser cannot change the session ID. A spec sends a real session ID in an unsigned cookie and gets 401.</li>
<li><strong><code>httponly</code>:</strong> JavaScript on the page cannot read it, so a script injected into the page cannot steal it.</li>
<li><strong><code>same_site: :lax</code>:</strong> browsers do not send it with a POST from another site. This is the only CSRF protection for now, and <code>todo.md</code> asks whether we need more.</li>
</ul>
<p>The controller is thin. Logging in is rate limited with Rails 8's <code>rate_limit</code>: ten tries in three minutes for each IP address.</p>
{code(B+"app/controllers/api/v1/sessions_controller.rb", "ruby")}
""")

# ---------------------------------------------------------------- 9
section("react", "9", "The React side", f"""
<p>All server data goes through TanStack Query. The session has one query key, <code>['authentication', 'session']</code>. After a command succeeds, React invalidates that key and refetches, so the screens always draw what the server says.</p>
{code(F+"src/features/authentication/sessionApi.ts", "typescript", note="The <code>retry</code> rule matters. TanStack Query retries failed requests three times by default. A 401 is an answer, not a network fault, so it must not be retried.")}
<p>The login form posts, refreshes the session query, and goes to the home page. On failure it shows the server's own message:</p>
{code(F+"src/features/authentication/LoginPage.tsx", "tsx", "export function LoginPage", "const submit", extra=-2)}
<p>The home page is where the session decides the screen. Not logged in goes to <code>/login</code>. More than one board shows the picker. Signed in shows the board and schools:</p>
{code(F+"src/pages/HomePage.tsx", "tsx")}
{code(F+"src/features/authentication/OrganizationPicker.tsx", "tsx", "export function OrganizationPicker", "onSuccess", extra=1)}
<p>The header in <code>AppLayout.tsx</code> shows <strong>Log out</strong> whenever a session exists. Logging out removes the cached session and goes to <code>/login</code>.</p>
""")

# ---------------------------------------------------------------- 10
section("demo", "10", "Demo data", f"""
<p><code>db/seeds.rb</code> loads the demo file only in development. The data comes from <code>etc/demo-school-data.txt</code>: three boards, three schools each, and one administrator for each school. One extra person, Morgan Crossway, administers schools in two boards, so the picker can be tried.</p>
{code(B+"db/seeds/demo.rb", "ruby", "module DemoData", "TWO_BOARD_ADMINISTRATOR = {", extra=-3)}
<p>Every write uses <code>find_or_create_by!</code>, so running the seeds twice changes nothing. The writes go straight to the models. That breaks the rule that every write goes through a command, because the commands to create boards, schools and users do not exist yet. <code>todo.md</code> records it.</p>
<p>Every demo account uses the password <code>permishly-demo</code>. Try <code>marsha.deepwater@eldritch-shores.example</code> for one board, or <code>morgan.crossway@example.com</code> for the picker.</p>
""")

# ---------------------------------------------------------------- 11
section("tests", "11", "How the tests prove it", f"""
<p>Each test was written before the code it covers, and was run to see it fail for the right reason first. The failures were real behaviour gaps: rows from both boards visible, 404s for missing endpoints, a login form that did not exist.</p>
<div class="table"><table>
<thead><tr><th>Spec</th><th>Proves</th></tr></thead>
<tbody>
<tr><td><code>spec/tenancy/row_level_security_spec.rb</code></td><td>Specs run as a role RLS applies to. One board's rows only. No board set: no rows. Cannot insert or reference across boards. The setting does not leak.</td></tr>
<tr><td><code>spec/capabilities/application_command_spec.rb</code></td><td>Writes land in the right board. Bad input writes nothing. A failure rolls back. A board is required unless the class opts out. Dependencies can be replaced.</td></tr>
<tr><td><code>spec/capabilities/application_query_spec.rb</code></td><td>Reads only the given board. Cannot write. Runs in a read-only transaction.</td></tr>
<tr><td><code>spec/capabilities/accounts/current_user_query_spec.rb</code></td><td>Tenant isolation for the query.</td></tr>
<tr><td><code>spec/requests/api/v1/session_spec.rb</code></td><td>The whole login over HTTP, below.</td></tr>
<tr><td><code>frontend/src/features/authentication/LoginFlow.test.tsx</code></td><td>The screens: redirect to login, log in, wrong password, picker, log out.</td></tr>
</tbody></table></div>
<p>The request spec reads like the requirements. This is the main case:</p>
{code(B+"spec/requests/api/v1/session_spec.rb", "ruby", "context \"when the administrator has a user in one organization\"", "it \"accepts the email", extra=-2)}
<p>The colleague in the setup was added after a mutation check. With a defect that showed every administrator's schools, all specs still passed, because no spec had two administrators in one board. With the colleague added, the defect fails a spec.</p>
<h3>Mutation checks</h3>
<p>No mutation tool is set up, so defects were put in by hand, one at a time, and the suite was run. Each was caught:</p>
<div class="table"><table>
<thead><tr><th>Defect put in</th><th>Specs failing</th></tr></thead>
<tbody class="num">
<tr><td>Current-user query skips the board</td><td>4</td></tr>
<tr><td>Login always picks the first board</td><td>2</td></tr>
<tr><td>Picking a board skips the membership check</td><td>1</td></tr>
<tr><td>Logout leaves the session row</td><td>1</td></tr>
<tr><td>Email not normalized</td><td>1</td></tr>
<tr><td>Board list not sorted</td><td>1</td></tr>
<tr><td>Every administrator's schools shown</td><td>1 (after the fix above)</td></tr>
<tr><td>Unsigned cookie accepted</td><td>6</td></tr>
<tr><td>Identity with no board allowed in</td><td>1</td></tr>
<tr><td><code>Tenancy</code> does not restore the board</td><td>4</td></tr>
</tbody></table></div>
<p>In React, four defects were tried, such as removing the redirect to login and not refreshing the session after picking a board. Each failed one test.</p>
""")

# ---------------------------------------------------------------- 12
section("traps", "12", "Traps worth knowing", """
<p>These cost time while building the feature. They are easy to hit again.</p>
<dl class="traps">
<dt>A superuser ignores RLS</dt>
<dd>Even with <code>FORCE</code>. Check the connection role before you trust a passing isolation test.</dd>
<dt>A reset setting is an empty string</dt>
<dd><code>current_setting</code> returns <code>''</code>, not null, after a transaction that set it ends. Cast it with <code>NULLIF</code>.</dd>
<dt><code>db:migrate</code> on an empty database loads <code>structure.sql</code></dt>
<dd>It does not run the migrations. A stale <code>structure.sql</code> gives you a stale database. Delete it and migrate when you change a migration that already ran.</dd>
<dt><code>pg_dump</code> must be the server's version or newer</dt>
<dd>Rails runs your local <code>pg_dump</code>. The server is Postgres 18. Homebrew libpq had to go from 17 to 18.</dd>
<dt>Grants do not survive a schema load</dt>
<dd>Rails dumps with <code>--no-privileges --no-owner</code>. Put grants and function owners in <code>db/privileges.sql</code>.</dd>
<dt>A test transaction hides transaction bugs</dt>
<dd>Anything about "the first statement in a transaction" needs a spec with <code>use_transactional_tests = false</code>.</dd>
<dt>A method name can hide a class attribute</dt>
<dd>A private method called <code>organization_required</code> silently replaced the attribute reader of the same name. The attribute is now <code>requires_organization</code>, readable only on the class.</dd>
</dl>
""")

# ---------------------------------------------------------------- 13
section("next", "13", "Not done yet", """
<ul>
<li>Sessions never expire. The cookie is permanent and the server keeps old sessions.</li>
<li>CSRF protection is <code>SameSite=Lax</code> only.</li>
<li>No Google login.</li>
<li>No screens or commands to create boards, schools or users. The seeds write directly.</li>
<li>No authorization model yet. "School administrator" is a table, not a role with permissions.</li>
<li>Production needs <code>PRIMARY_DATABASE_URL</code> and <code>OWNER_DATABASE_URL</code>, and a password for <code>permishly_app</code>.</li>
</ul>
<p>These are listed in <code>todo.md</code>.</p>
""")

w.render(Path(__file__).resolve().parent.parent / "2026-11-17-login-and-foundations.html")
