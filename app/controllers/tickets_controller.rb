class TicketsController < ApplicationController
  def create
    message = params[:message]
    parsed_ticket = ChatGPTParser.parse_ticket(message)

    return render json: { error: parsed_ticket[:error] }, status: :unprocessable_entity if parsed_ticket[:error]

    trello_service = TrelloService.new
    result = trello_service.create_card(parsed_ticket["client"], parsed_ticket["title"], parsed_ticket["description"], parsed_ticket["assignee"], parsed_ticket["column"])

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result
    end
  end
end