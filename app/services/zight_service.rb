require 'nokogiri'
require 'open-uri'

class ZightService
  def self.extract_image(zight_url)
    return nil unless zight_url

    begin
      # Fetch the Zight page HTML
      html = URI.open(zight_url).read
      doc = Nokogiri::HTML(html)

      image_node = doc.at_css('meta[property="og:image"]')
      image_url = image_node['content'] if image_node

      if image_url
        Rails.logger.info "✅ Extracted Zight Image URL: #{image_url}"
        image_url
      else
        Rails.logger.error "❌ No image found in Zight link."
        nil
      end
    rescue => e
      Rails.logger.error "❌ Failed to fetch Zight image: #{e.message}"
      nil
    end
  end
end