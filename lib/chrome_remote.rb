require "chrome_remote/version"
require "chrome_remote/client"
require "json"
require "net/http"

module ChromeRemote
  class << self
    DEFAULT_OPTIONS = {
      host: "localhost",
      port: 9222,
      pages: 30,
      robin: nil
    }

    def client(**options)
      options = DEFAULT_OPTIONS.merge(options)
      Client.new(get_ws_url(options))
    end

    def close_all_pages(options = {})
      options = DEFAULT_OPTIONS.merge(options)
      response = Net::HTTP.get(options[:host], "/json", options[:port])
      response = JSON.parse(response)
      pages = response.select {|e| e["type"] == "page"}
      pages.each do |pg|
        chrome = Client.new(pg["webSocketDebuggerUrl"])
        chrome.send_cmd "Page.close"
      end
    end

    private

    def get_ws_url(options)
      return get_ws_url_rr(options) if options[:robin]
      pages = get_pages(options)
      page = if pages.length > 0
        pages.sample
      else
        create_new_page(options)
      end
      page["webSocketDebuggerUrl"]
    end

    def get_ws_url_rr(options)
      pages = get_pages(options)
      if pages.count < options[:pages]
        t = options[:pages] - pages.count
        t.times { pages << create_new_page(options) }
      end
      urls = pages.map {|e| e["webSocketDebuggerUrl"]}
      options[:robin].next(urls)
    end

    def get_pages(options)
      response = Net::HTTP.get(options[:host], "/json", options[:port])
      response = JSON.parse(response)
      response.select {|e| e["type"] == "page"}
    end

    def create_new_page(options)
      response = Net::HTTP.get(options[:host], "/json/new", options[:port])
      JSON.parse(response)
    end

  end
end
