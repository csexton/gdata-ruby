require File.dirname(__FILE__)+'/base'

module GData

  class Spreadsheet < GData::Base
    attr_accessor :worksheet_id
    
    def initialize(spreadsheet_id)
      @spreadsheet_id = spreadsheet_id
      @worksheet_id = 1
      super 'wise', 'gdata-ruby', 'spreadsheets.google.com'
    end

    def evaluate_cell(cell)
      path = "/feeds/cells/#{@spreadsheet_id}/#{@worksheet_id}/#{@headers ? "private" : "public"}/basic/#{cell}"
      doc = Hpricot(request(path))
      result = (doc/"content[@type='text']").inner_html
    end
    
    #GET Worksheet ID
    def get_worksheet_id_of(worksheet_name)
      path = "/feeds/worksheets/#{@spreadsheet_id}/#{@headers ? "private" : "public"}/full"
      doc = Hpricot(request(path))
      res1 = (doc/"content[@type='text']")
      el_idx = 0
      res1.each_with_index { |el, i| el_idx = i if el.inner_text.eql?(worksheet_name) }
      # el_idx = res1.inject(0) { |i, el| i += 1; el.inner_text.eql?(sheet_title) ? i : nil }
      (doc/"link[@rel='self'][@href]")[el_idx + 1]['href'][/\/=?(\w+)$/,1]
    end

    def save_entry(entry)
      path = "/feeds/cells/#{@spreadsheet_id}/#{@worksheet_id}/#{@headers ? 'private' : 'public'}/full"
      post(path, entry)
    end

    def entry(data)
      value = @formula ? '='+data : data
      <<XML
  <entry xmlns="http://www.w3.org/2005/Atom" xmlns:gs="http://schemas.google.com/spreadsheets/2006">
    <gs:cell row="#{@row}" col="#{@col}" inputValue="#{value}" />
  </entry>
XML
    end
    
    # def add_to_cell(data, cell, options = {})
    #   convert_to_row_col(cell)
    #   save_entry( entry(data, options) )
    # end
    
    def add(data, options = {})
      raise GData::Exceptions::Spreadsheet::UnspecifiedCell if options[:to].nil?
      @cell = options[:to] 
      @formula = ( options[:formula] || false ) 
      convert_to_row_col
      save_entry(entry(data))
    end
    
    def convert_to_row_col
      @cell.match(/^R(\d+)C(\d+)$/)
      @row, @col = $1, $2
    end
    
  end

end
