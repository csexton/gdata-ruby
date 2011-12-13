require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/gdata/webmaster_tools'

describe GData::WebmasterTools do
  describe 'sites' do
    before(:each) do
      xml = fixture_xml('/fixtures/webmaster_tools/sites.xml')

      @wt = GData::WebmasterTools.new
      @wt.should_receive(:get).with('/webmasters/tools/feeds/sites/').and_return([nil, xml])
      @wt.should_receive(:authenticated?).and_return(true)
    end

    it 'should parse all fields from feed for all sites' do
      data = @wt.sites
      data.length.should eql(2)

      site1 = data[0]
      site2 = data[1]

      site1[:title].should eql('http://www.mysite.com/')
      site1[:id].should eql('http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.mysite.com%2F')
      site1[:verification_methods][:metatag].should eql('<meta name="verify-v1" content="nVryYYKT4lSCwaZ/avK1utx6/gtm78x9latRJPCdCuk=" >')
      site1[:verification_methods][:htmlpage].should eql('google937559d39027a39d.html')
      site1[:verified].should be_true

      site2[:title].should eql('http://www.myothersite.com/')
      site2[:id].should eql('http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.myothersite.com%2F')
      site2[:verified].should be_false
    end
  end

  describe 'site' do
    before(:each) do
      xml = fixture_xml('/fixtures/webmaster_tools/site.xml')

      @wt = GData::WebmasterTools.new
      @wt.should_receive(:get).and_return([nil, xml])
      @wt.should_receive(:authenticated?).and_return(true)
    end

    it 'should parse all fields from feed for given site' do
      data = @wt.site('http://www.mysite.com')

      data[:title].should eql('http://www.mysite.com/')
      data[:id].should eql('http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.mysite.com%2F')
      data[:verification_methods][:metatag].should eql('<meta name="verify-v1" content="nVryYYKT4lSCwaZ/avK1utx6/gtm78x9latRJPCdCuk=" >')
      data[:verification_methods][:htmlpage].should eql('google937559d39027a39d.html')
      data[:verified].should be_false
    end
  end

  describe 'add_site' do
    before(:each) do
      xml = fixture_xml('/fixtures/webmaster_tools/add_site.xml')

      @wt = GData::WebmasterTools.new
      @wt.should_receive(:post).and_return([Net::HTTPCreated.new(nil, nil, nil), xml])
      @wt.should_receive(:authenticated?).and_return(true)
    end

    it 'should return site data hash for freshly created site' do
      data = @wt.add_site('http://mynewsite.com')
      data[:title].should eql('http://www.mynewsite.com/')
      data[:verification_methods][:metatag].should eql('<meta name="verify-v1" content="nVryYYKT4lSCwaZ/avK1utx6/gtm78x9latRJPCdCuk=" >')
      data[:verification_methods][:htmlpage].should eql('google937559d39027a39d.html')
      data[:verified].should be_false
      data[:indexed].should be_false
    end
  end

  describe 'verify_site' do
    before(:each) do
      @xml = fixture_xml('/fixtures/webmaster_tools/verify_site.xml')
      @wt = GData::WebmasterTools.new
    end

    it 'should return true if verification succeeds' do
      @wt.should_receive(:put).and_return([Net::HTTPOK.new(nil, nil, nil), @xml])
      @wt.should_receive(:authenticated?).and_return(true)
      @wt.verify_site('http://www.mysite.com/', 'metatag').should be_true
    end

    it 'should raise an error if invalid method is supplied' do
      lambda {
        @wt.verify_site('http://www.mysite.com/', 'meta-tag')
      }.should raise_error(GData::WebmasterToolsError)
    end

    it 'should raise site not found error if account does not have this site' do
      @wt.should_receive(:put).and_return([Net::HTTPNotFound.new(nil, nil, nil), ''])
      @wt.should_receive(:authenticated?).and_return(true)
      lambda {
        @wt.verify_site('http://www.unknownsite.com', 'metatag')
      }.should raise_error(GData::WebmasterToolsError)
    end
  end

  describe 'delete_site' do
    it 'should raise WebmasterToolsError when site is not found or is missing'
  end

  describe 'keywords' do
    before(:each) do
      xml = fixture_xml('/fixtures/webmaster_tools/keywords.xml')

      @wt = GData::WebmasterTools.new
      @wt.should_receive(:get).and_return([nil, xml])
      @wt.should_receive(:authenticated?).and_return(true)
    end

    it 'should parse all keywords from keyword feed for site' do
      keywords = @wt.keywords('http://www.mysite.com')

      keywords.length.should eql(4)

      # data[:title].should eql('http://www.mysite.com/')
      # data[:id].should eql('http://www.google.com/webmasters/tools/feeds/sites/http%3A%2F%2Fwww.mysite.com%2F')
      # data[:verification_methods][:metatag].should eql('<meta name="verify-v1" content="nVryYYKT4lSCwaZ/avK1utx6/gtm78x9latRJPCdCuk=" >')
      # data[:verification_methods][:htmlpage].should eql('google937559d39027a39d.html')
      # data[:verified].should be_false
    end
  end

  describe 'crawl issues' do
    before(:each) do
      xml_page_1 = fixture_xml('/fixtures/webmaster_tools/crawl_errors_page_1.xml')
      xml_page_2 = fixture_xml('/fixtures/webmaster_tools/crawl_errors_page_2.xml')

      @wt = GData::WebmasterTools.new
      @wt.should_receive(:get).and_return([nil, xml_page_1], [nil, xml_page_2])
      @wt.should_receive(:authenticated?).and_return(true)
    end

    it 'should parse all crawl issues, and query for next page of results.' do
      crawl_errors = @wt.crawl_issues('http://www.site.com')
      crawl_errors.length.should eql(2)

      crawl_errors.each do |crawl_error|
        crawl_error.length.should eql(9)
      end
    end
  end

  def fixture_xml(path)
    File.read(File.dirname(__FILE__) + path)
  end
end
