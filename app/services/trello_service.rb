require 'active_support/inflector/transliterate' # Needed for accent removal
require 'fuzzy_match'
require 'httparty'

class TrelloService
  include HTTParty
  base_uri 'https://api.trello.com/1'

  def initialize
    @auth = { key: ENV['TRELLO_API_KEY'], token: ENV['TRELLO_TOKEN'] }
    @board_id = ENV['TRELLO_BOARD_ID']
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
      idLabels: label_id ? [label_id] : [],
      idMembers: member_id ? [member_id] : []
    }))

    Rails.logger.info "📤 Trello API Response: #{response.body}"

    return { error: "Failed to create card" } unless response.success?

    card_data = response.parsed_response
    {
      ticket_url: card_data['shortUrl'],
      details: {
        title: title,
        description: description,
        label: label,
        assignee: assignee,
        column: column
      }
    }
  end

  private

  def get_list_id(column_name)
    response = self.class.get("/boards/#{@board_id}/lists", query: @auth)
    return nil unless response.success?

    lists = response.parsed_response.map { |l| [l['name'].strip.downcase, l['id']] }.to_h
    lists[column_name.strip.downcase] || nil
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
end