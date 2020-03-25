require 'httparty'
require 'nokogiri'

class Scraper
  DEFAULT_OPTIONS = {
    base_url: 'https://example.com',
    path: 'listing',
    param: 'page',
    page: 1,
    per_page: 50,
    total: 200,
    last_page: 4,
    parent: {
      element: 'div',
      name: 'listingCard',
      type: 'class'
    },
    targets: [
      { key: :title, element: 'span', name: 'title', type: :class },
      { key: :company, element: 'span', name: 'company', type: :class },
      { key: :location, element: 'span', name: 'location', type: :class },
      { key: :url, element: 'a', name: nil, type: :href }
    ]
  }

  attr_accessor :options, :results

  def initialize
    @options = DEFAULT_OPTIONS
    @results = []
  end

  # This method will trigger our paginated scraper. It will get the first page result,
  # And use the specified parent element, identifier and attribute type to set the per page/ last page values if necessary.
  # and the last page for our options. Then we will trigger our paginated get with this new information.
  #
  # @param element [String] the HTML element for the recurring parent element on the page
    # ex: 'div' or 'h1'
  # @param name [String] the class or id name we can target on the element.
    # ex: 'listingCard' if the class name for the element we want to target is 'listingCard'
  # @param type [Symbol] the HTML attribute type for the recurring parent element on the page
    # ex: :class or :id
  def run
    page = scrape_page(@options[:base_url])

    @options[:per_page] = page.css(parent_target).count
    @options[:last_page] = get_last_page(@options[:total], @options[:per_page])

    paginated_get(@options[:current_page], @options[:last_page])
  end

  # Specify the attribute type format needed for nokogiri data parsing
  #
  # @param type [Symbol] the attribute type on the html element
  # valid options currently are :class or :id
  # @return [String] the format needed for nokogiri data parsing ('.' for class or '#' for id)
  def set_attribute_type(type)
    type == :class ? '.' : '#'
  end

  # Set the parent element for nokogiri parsing
  # ex: 'div.listingCard'
  def parent_target
    parent = @options[:parent]

    return parent[:element] if parent[:name].nil? || parent[:type].nil?

    attribute_type = set_attribute_type(parent[:type])

    [parent[:element], attribute_type, parent[:name]].join
  end

  def scrape_page(url)
    Nokogiri::HTML(HTTParty.get(url))
  end

  # @param total [Integer] the total number of elements in the full data set
  # @param per_page [Integer] the number of elements per page
  def get_last_page(total, per_page)
    (total.to_f/per_page.to_f).ceil
  end

  def paginated_get
    return unless @options[:last_page]

    while @options[:current_page] <= @options[:last_page]
      get_next_page; @options[:current_page] += 1
    end
  end

  def get_next_page
    page_url = [@url, @options[:path], '?', @options[:param], '=', @options[:current_page]].join

    data = scrape_page(page_url).css(parent_target)

    format_results(data)
  end

  def format_results(page_items)
    page_items.each { |page_item| @results << format_result(page_item) }
  end

  def format_result(page_item)
    @options[:targets].each_with_object({}) do |t, obj|
      next obj[t[:key]] = get_href_value(page_item) if t[:type] == :href

      type = set_attribute_type(t[:type])
      value = [t[:element], type, t[:name]]

      obj[t[:key]] = page_item.css(value)
    end
  end

  def get_href_value(page_item)
    page_item.css('a')[0].attributes['href'].value
  end
end

# Example:
# scraper = Scraper.new
# scraper.run
# scraper.results
