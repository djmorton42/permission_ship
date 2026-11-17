# Database tasks run as the owner role. See config/database.yml.
#
# Some tasks (for example db:migrate:redo) use ActiveRecord::Base, which
# connects as the app role. The app role cannot change the schema, so every
# db: task connects ActiveRecord::Base as the owner.
Rake::Task["db:load_config"].enhance do
  owner = ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env, name: "owner")
  ActiveRecord::Base.establish_connection(owner) if owner
end

# db/privileges.sql grants the app role its privileges.
namespace :db do
  desc "Create the database roles and grant their privileges (db/privileges.sql)"
  task privileges: :load_config do
    DatabasePrivileges.apply(ActiveRecord::Tasks::DatabaseTasks.env)
  end

  namespace :test do
    task privileges: :load_config do
      DatabasePrivileges.apply("test")
    end
  end
end

module DatabasePrivileges
  SQL_FILE = Rails.root.join("db/privileges.sql")

  def self.apply(env)
    ActiveRecord::Base.configurations.configs_for(env_name: env, name: "owner").then do |config|
      next unless config

      hash = config.configuration_hash
      connection = PG.connect(
        host: hash[:host], port: hash[:port], user: hash[:username], password: hash[:password],
        dbname: hash[:database], gssencmode: hash[:gssencmode] || "prefer"
      )
      begin
        connection.exec(SQL_FILE.read)
        set_local_app_password(connection, env)
      ensure
        connection.close
      end
    end
  end

  # Local environments set a known password. Other environments set it outside the app.
  def self.set_local_app_password(connection, env)
    return unless %w[development test].include?(env)

    app = ActiveRecord::Base.configurations.configs_for(env_name: env, name: "primary", include_hidden: true).configuration_hash
    connection.exec("ALTER ROLE #{connection.quote_ident(app[:username])} " \
                    "PASSWORD #{connection.escape_literal(app[:password])}")
  end
end

%w[db:migrate db:schema:load db:prepare db:rollback].each do |name|
  Rake::Task[name].enhance { Rake::Task["db:privileges"].execute }
end
Rake::Task["db:test:prepare"].enhance { Rake::Task["db:test:privileges"].execute }
