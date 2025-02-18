require 'openai'

class ChatGPTParser
  def self.parse_ticket(message)
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

    prompt = <<~PROMPT
      Extract structured data from the following user message. 
      The user is asking to create a ticket in a project management tool.
      
      User Message: "#{message}"
      
      Return JSON with:
      - client: The client name (or "General" if not mentioned).
      - title: The ticket title.
      - description: The ticket details.
      - assignee: The assignee's name (or "Unassigned" if not specified).
      - column: The project board column (e.g., "Backlog", "In Progress").

      Example Output:
      {
        "client": "ACME Corp",
        "title": "Fix Login Issue",
        "description": "Users are reporting login failures.",
        "assignee": "JohnDoe",
        "column": "Backlog"
      }
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4", # or "gpt-3.5-turbo" for a cheaper option
        messages: [{ role: "system", content: prompt }],
        temperature: 0.2
      }
    )

    begin
      JSON.parse(response.dig("choices", 0, "message", "content"))
    rescue JSON::ParserError
      { error: "Failed to parse response from ChatGPT" }
    end
  end
end