require "active_support/inflector/transliterate" # Needed for accent removal
require "fuzzy_match"
require "httparty"

LIST_MAPPINGS = {
  "On Hold/Backlog" => "6413b12ddd0200ded879904f",
  "Needs Design" => "60ec976db7a27c15f456a442",
  "Design In Progress" => "6442eb26aa4e103b7e71de51",
  "Design Ready for Review" => "646c08e063e0bd2ea9add8ce",
  "Ready for Development" => "60ec97585607b146f583c8bc",
  "Development in Progress" => "60ec975dcf0d1a6599970e80",
  "Ready for Testing" => "60ec9765fe4c8302f2af3360",
  "Ready for Release" => "645423ae58c8016ad550f185",
  "Shipped" => "6789509de06fd755163cfb01"
}

class TrelloService
  include HTTParty
  base_uri "https://api.trello.com/1"

  def initialize
    @auth = { key: ENV["TRELLO_API_KEY"], token: ENV["TRELLO_TOKEN"] }
    @board_id = ENV["TRELLO_BOARD_ID"]
    @mappings = YAML.load_file(Rails.root.join("config", "trello_mappings.yml"))
  end

  def create_card(title, description, label, assignee, column)
    list_id = get_list_id(column)
    return { error: "Column '#{column}' not found" } unless list_id

    member_id = get_member_id(assignee)
    label_id = get_label_id(label)

    Rails.logger.info "📌 Creating Trello Card with:"
    Rails.logger.info "📝 Title: #{title}"
    Rails.logger.info "📃 Description: #{description}"
    Rails.logger.info "🏷 Label ID: #{label_id}"
    Rails.logger.info "👤 Assignee ID: #{member_id}"
    Rails.logger.info "📂 List ID: #{list_id}"

    response = self.class.post("/cards", query: @auth.merge({
      idList: list_id,
      name: "#{title}",
      desc: description,
      idLabels: label_id ? [ label_id ] : [],
      idMembers: member_id ? [ member_id ] : []
    }))

    Rails.logger.info "📤 Trello API Response: #{response.body}"


    if response.success?
      ticket_id = response.parsed_response["id"]
      ticket_url = response.parsed_response["shortUrl"]
      Rails.logger.info "✅ Trello Card Created: #{ticket_url}"
      { ticket_id: ticket_id, ticket_url: ticket_url }
    else
      Rails.logger.error "❌ Trello Card Creation Failed: #{response.body}"
      { error: response.body }
    end

    card_data = response.parsed_response
    {
      ticket_url: card_data["shortUrl"],
      details: {
        title: title,
        description: description,
        label: label,
        assignee: assignee,
        column: column
      }
    }
  end

  def get_list_id(column_name)
    list_names = LIST_MAPPINGS.keys.map(&:downcase)
    matcher = FuzzyMatch.new(list_names)

    best_match = matcher.find(column_name.downcase.strip)
    list_id = LIST_MAPPINGS[LIST_MAPPINGS.keys.find { |k| k.downcase.strip == best_match }]


    if list_id
      Rails.logger.info "✅ Fuzzy Matched List: '#{column_name}' → '#{best_match}' (#{list_id})"
      list_id
    else
      Rails.logger.error "❌ Column '#{column_name}' not found in Trello"
      nil
    end
  end

  def get_member_id(assignee)
    return nil if assignee.nil?

    Rails.logger.info "🔍 Searching for Member: '#{assignee}'"

    normalized_assignee = ActiveSupport::Inflector.transliterate(assignee).strip.downcase
    normalized_members = @mappings["members"].transform_keys { |name|
      ActiveSupport::Inflector.transliterate(name).strip.downcase
    }

    Rails.logger.info "🔍 Available Members: #{normalized_members.keys}"

    if normalized_members.key?(normalized_assignee)
      Rails.logger.info "✅ Exact Match Found: #{normalized_members[normalized_assignee]}"
      return normalized_members[normalized_assignee]
    end

    fuzzy_matcher = FuzzyMatch.new(normalized_members.keys)
    best_match = fuzzy_matcher.find(normalized_assignee)

    if best_match
      Rails.logger.info "✅ Fuzzy Matched Member: #{best_match} → #{normalized_members[best_match]}"
      return normalized_members[best_match]
    end

    Rails.logger.warn "⚠️ No match found for member '#{assignee}'"
    nil
  end

  def get_label_id(label_name)
    return nil if label_name.nil?

    Rails.logger.info "🔍 Searching for Label: '#{label_name}'"

    normalized_label = ActiveSupport::Inflector.transliterate(label_name).strip.downcase
    normalized_labels = @mappings["labels"].transform_keys { |name|
      ActiveSupport::Inflector.transliterate(name).strip.downcase
    }

    Rails.logger.info "🔍 Available Labels: #{normalized_labels.keys}"

    if normalized_labels.key?(normalized_label)
      Rails.logger.info "✅ Exact Match Found: #{normalized_labels[normalized_label]}"
      return normalized_labels[normalized_label]
    end

    fuzzy_matcher = FuzzyMatch.new(normalized_labels.keys)
    best_match = fuzzy_matcher.find(normalized_label)

    if best_match
      Rails.logger.info "✅ Fuzzy Matched Label: #{best_match} → #{normalized_labels[best_match]}"
      return normalized_labels[best_match]
    end

    Rails.logger.warn "⚠️ No match found for label '#{label_name}'"
    nil
  end

  def upload_attachment(card_id, image_url)
    return unless card_id && image_url

    Rails.logger.info "📤 Uploading image to Trello: #{image_url}"

    response = self.class.post("/cards/#{card_id}/attachments", query: @auth.merge({
      url: image_url,
      name: "Screenshot"
    }))

    if response.success?
      Rails.logger.info "✅ Image uploaded to Trello: #{response.parsed_response["url"]}"
      response.parsed_response["url"]
    else
      Rails.logger.error "❌ Failed to upload image to Trello: #{response.body}"
      nil
    end
  end
end
