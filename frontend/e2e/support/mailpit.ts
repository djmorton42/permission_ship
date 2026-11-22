import { expect } from '@playwright/test'

// Reads mail that the API sent to Mailpit (docker-compose.yml).
// Development and browser tests share one Mailpit, so find a message by its
// recipient and the time it arrived. Do not delete messages: that would empty
// the developer's inbox.
const mailpitUrl = process.env.MAILPIT_URL ?? 'http://localhost:8025'

export type Email = {
  subject: string
  from: string
  to: string[]
  text: string
  html: string
}

type Address = { Address: string }
type MessageSummary = { ID: string; Created: string }
type Message = { Subject: string; From: Address; To: Address[]; Text: string; HTML: string }

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(`${mailpitUrl}${path}`)
  if (!response.ok) throw new Error(`Mailpit ${path} returned ${response.status}`)
  return (await response.json()) as T
}

// Waits for the newest message to `to` that arrived after `receivedAfter`.
// Take `receivedAfter` just before the action that sends the mail.
export async function waitForEmail({ to, receivedAfter }: { to: string; receivedAfter: Date }): Promise<Email> {
  const query = encodeURIComponent(`to:"${to}"`)
  let id: string | undefined

  await expect
    .poll(
      async () => {
        const { messages } = await getJson<{ messages: MessageSummary[] }>(`/api/v1/search?query=${query}`)
        // Mailpit lists the newest message first.
        id = messages.find((message) => new Date(message.Created) > receivedAfter)?.ID
        return id
      },
      { message: `an email to ${to}`, timeout: 10_000 },
    )
    .toBeDefined()

  const message = await getJson<Message>(`/api/v1/message/${id}`)
  return {
    subject: message.Subject,
    from: message.From.Address,
    to: message.To.map((address) => address.Address),
    text: message.Text,
    html: message.HTML,
  }
}
