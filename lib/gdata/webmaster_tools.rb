# Ex    tension class into Ruby GData library for use Google Webmaster Tools.
#
# == Overview
#
# This class enables to perform all actions on Google Webmaster Tools account: getting information about sites
# associated with an authenticated account and submitting new sites to this account.
#
# See more at http://code.google.com/apis/webmastertools/
#

require 'cgi'
require 'date'
require 'rexml/document'
require File.dirname(__FILE__) + '/base'

module GData #:nodoc:

  class WebmasterToolsError < StandardError; end #:nodoc:

  class WebmasterTools < GData::Base

    BASE_URL = '/webmasters/tools/feeds'
    FEED_URL = BASE_URL + '/sites/'
    KEYWORDS_URL = BASE_URL + "/%s/keywords/"
    CRAWL_ISSUES_URL = BASE_URL + "/%s/crawlissues/"


    def initialize
      super('sitemaps', 'gdata-ruby', 'www.google.com')
    end

    # Get feed for all sites associated with authenticated user and parse all data into hash.
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.sites
    #   => [{:id => ..., :title => ..., ...}, {:id => ..., :title => ..., ...}]
    #
    # Each element in returned array contains hash with site data. See more at parse_site_entry.
    def sites
      if authenticated?
        response, data = get(FEED_URL)

        site_data = Array.new
        REXML::Document.new(data).root.elements.each('entry') do |e|
          # puts e
          site_data << parse_site_entry(e)
        end
        site_data
      else
        raise NotAuthenticatedError
      end
    end

    # Get feed for selected site under account.
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.site('http://www.mysite.com')
    #   => {:id => ..., :title => ..., ...}
    #
    # Returned hash contains site data parsed with parse_site_entry method.
    def site(site_id)
      if authenticated?
        response, data = get(site_feed(site_id))
        # puts data
        # entry = REXML::Document.new(data).root.elements['entry']
        entry = REXML::Document.new(data).root
        parse_site_entry(entry)
      else
        raise NotAuthenticatedError
      end
    end

    # Add new site to account. Returns hash for created site.
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.add_site('http://www.mynewsite.com')
    #   => {:id => ..., :title => ..., ...}
    #
    # Returned hash contains site data parsed with parse_site_entry method.
    def add_site(url)
      if authenticated?
        content = '<entry xmlns="http://www.w3.org/2005/Atom"><content src="' + url +'" /></entry>'
        response, data = post(FEED_URL, content)

        case response
        when Net::HTTPCreated
          entry = REXML::Document.new(data).root
          return parse_site_entry(entry)
        when Net::HTTPForbidden
          raise WebmasterToolsError.new(data)
        else
          raise WebmasterToolsError
        end
      else
        raise NotAuthenticatedError
      end
    end

    # Remove site from account.
    def delete_site(site_id)
      if authenticated?
        response, data = delete site_feed(site_id)

        case response
        when Net::HTTPOK
          return true
        else
          raise WebmasterToolsError.new(data)
        end
      else
        raise NotAuthenticatedError
      end
    end

    # Initiates site ownership verification process in Webmaster Tools account.
    #
    # == Usage
    #
    # Method can be only 'htmlpage' or 'metatag', otherwise this method will raise WebmasterToolsError.
    def verify_site(site_id, method)
      raise WebmasterToolsError unless ['htmlpage', 'metatag'].include?(method)

      if authenticated?
        content = '<entry xmlns="http://www.w3.org/2005/Atom" xmlns:wt="http://schemas.google.com/webmasters/tools/2007">'
        content << '<id>' + site_id + '</id><category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/webmasters/tools/2007#site-info"/>'
        content << '<wt:verification-method type="' + method + '" in-use="true"/>'
        content << '</entry>'
        response, data = put(site_feed(site_id), content)

        case response
        when Net::HTTPOK
          entry = REXML::Document.new(data).root
          data = parse_site_entry(entry)

          if data[:verified] and data[:title] == site_id
            return true
          else
            return false
          end
        when Net::HTTPNotFound
          raise WebmasterToolsError.new(data)
        else
          raise WebmasterToolsError
        end
      else
        raise NotAuthenticatedError
      end
    end

    # Get keywords feed for selected site under account.
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.keywords('http://www.mysite.com')
    #   => [{:keyword => ..., :source => ...}, ...]
    #
    # Returned hash contains keyword data parsed with parse_keyword_entry method.
    def keywords(site_id)
      if authenticated?
        response, data = get(keywords_feed(site_id))

        keywords = Array.new
        REXML::Document.new(data).root.elements.each('wt:keyword') do |e|
          keywords << {
            :keyword => e.get_text.to_s,
            :source => e.attributes['source']
          }
        end
        keywords
      else
        raise NotAuthenticatedError
      end
    end

    # Get feed of crawl issues for a site
    #
    # == Example
    #
    #   wt = GData::WebmasterTools.new
    #   wt.authenticate('username@gmail.com', 'password')
    #   wt.crawl_issues('http://www.example.com')
    #
    # Each element in returned array contains hash with crawl issue data.
    def crawl_issues(site_id)
      if authenticated?
        crawl_issues_for_url(CRAWL_ISSUES_URL % [CGI::escape(site_id)]).flatten
      else
        raise NotAuthenticatedError
      end
    end

    private

    def crawl_issues_for_url(url)
      response, data = get(url)

      crawl_issues = Array.new
      REXML::Document.new(data).root.elements.each('entry') do |e|
        crawl_issues << element_to_hash(e)
      end

      # get next page of results
      REXML::Document.new(data).root.elements.each('link') do |l|
        link = element_to_hash(l)
        crawl_issues << crawl_issues_for_url(link[:href]) if link[:rel] == 'next'
      end

      crawl_issues
    end

    # Private helper method to compose site feed based on site id.
    def site_feed(site_id)
      FEED_URL + CGI::escape(site_id || '')
    end

    # Private helper method to compose keywords feed based on site id.
    def keywords_feed(site_id)
      KEYWORDS_URL % [CGI::escape(site_id || '')]
    end

    # Parses site entry into hash from feed partial.
    #
    # == Site data hash format
    #
    #   {
    #     :id => 'http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.mysite.com%2F',
    #     :title => 'http://www.mysite.com', :updated => DateTime..., :indexed => true, :verified => true,
    #     :crawled => DateTime...,
    #     :verification_methods => {:metatag => '<meta ...>', :htmlpage => 'google....html'}
    #   }
    #
    def parse_site_entry(elem)
      entry = element_to_hash elem

      entry[:verification_methods] = {}
      elem.elements.each('wt:verification-method') do |m|
        entry[:verification_methods][m.attributes['type'].to_sym] = CGI::unescapeHTML(m.get_text.to_s.gsub("\\", ""))
      end

      entry
    end

    def element_to_hash parent
      hash = {}
      (parent.elements.to_a + parent.attributes.to_a).each do |element|
        key = element.name.gsub(/^.*:/i, '').gsub(/[^a-z0-9]+/i, '_').to_sym

        if element.kind_of? REXML::Element
          # || element.has_attributes?
          value = element.has_elements? ? element_to_hash(element) : element.get_text.to_s
        else
          value = element.to_s
        end

        unless value.empty?
          if hash[key]
            hash[key] = [hash[key]] unless hash[key].respond_to?(:push)
            hash[key].push value
          else
            value = value == 'true' if (value == 'true' || value == 'false')
            hash[key] = value
          end
        end
      end
      # hash[:value] = parent.get_text if parent.has_text?
      hash
    end
  end
end
