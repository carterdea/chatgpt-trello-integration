class TicketsController < ApplicationController
  def create
    message = params[:message]
    logger.info "Received ticket creation request: #{message}"

    parsed_ticket = ChatgptParser.parse_ticket(message)

    if parsed_ticket[:error]
      logger.error "Ticket creation failed: #{parsed_ticket[:error]}"
      return render json: { error: parsed_ticket[:error] }, status: :unprocessable_entity
    end

    trello_service = TrelloService.new
    result = trello_service.create_card(
      parsed_ticket["title"],
      parsed_ticket["description"],
      parsed_ticket["label"],
      parsed_ticket["assignee"],
      parsed_ticket["column"]
    )

    if result[:error]
      logger.error "Trello ticket creation failed: #{result[:error]}"
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      logger.info "Ticket successfully created: #{result[:ticket_url]}"
      render json: result

      # ✅ Extract the Zight URL from parsed_ticket
      zight_url = parsed_ticket["zight_url"]

      if zight_url
        logger.info "📸 Zight URL detected: #{zight_url}"
        image_url = ZightService.extract_image(zight_url)

        if image_url
          logger.info "✅ Extracted image URL: #{image_url}"
          trello_service.upload_attachment(result[:ticket_id], image_url)
        else
          logger.error "❌ Failed to extract image from Zight URL."
        end
      end
    end
  end
end