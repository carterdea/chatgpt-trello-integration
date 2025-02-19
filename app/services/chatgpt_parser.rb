require 'openai'

class ChatgptParser
  def self.parse_ticket(message)
    client = OpenAI::Client.new(access_token: ENV.fetch('OPENAI_API_KEY')) # ruby-openai expects `access_token`

    prompt = <<~PROMPT
      Extract structured data from the following message about creating a project management ticket.

      **User Message:**  
      "#{message}"

      **Return JSON ONLY in this exact structure (NO extra text or explanations):**
      {
        "title": "SHORT, clear summary of what is being asked for",
        "description": "Detailed explanation with expected behavior, client expectations, or steps to reproduce a bug",
        "label": "MUST BE one of the following: ['New Era Cap', 'New Era', 'House of Noa', 'Momentary Ink', 'BLOCKED', 'MiniLuxe', 'Granarly', 'North Star', 'Reeis', 'Wildlike', 'Toto Foods', 'Texas True Threads', 'Stussy', 'Buffalo Market', 'Ahh Gave', 'Piano Technician Academy', 'Bonjour Fête', 'G-Form', 'Stillwell Pianos', 'Eternal Water', 'Essential Hair Academy', 'Welle Brand', 'Flower Shop', 'Krystal Labs', 'Sport Drink', 'American Threads']. If no exact match, return 'General'.",
        "assignee": "Person responsible for the task (default: 'Unassigned')",
        "column": "The Trello board column, e.g., 'Needs Design/Backlog', 'Development In Progress', 'Needs Design', if none specified, use 'Ready for Development'"
      }
      **Rules:**
      - `"title"`: Must be **10 words or less**, summarizing the request.
      - `"description"`: Must **not** repeat the title but provide **more details**.
      - `"label"`: **MUST match one from the provided list**. If uncertain, return `"General"`.
      - **DO NOT** include any extra text outside the JSON.
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4", # Use GPT-4 for better accuracy
        messages: [{ role: "user", content: prompt }],
        temperature: 0.2
      }
    )

    
    raw_response = response["choices"][0]["message"]["content"] rescue nil
    Rails.logger.info "🤖 Raw ChatGPT Response: #{raw_response.inspect}"

    begin
      parsed_response = JSON.parse(raw_response)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Failed to parse ChatGPT response: #{e.message}"
      Rails.logger.error "📜 Raw response content: #{raw_response.inspect}"
      return { error: "Failed to parse response from ChatGPT" }
    end

    Rails.logger.info "✅ Parsed Response: #{parsed_response.inspect}"

    parsed_response["title"] ||= "Untitled"
    parsed_response["label"] ||= "General"

    parsed_response
  end
end