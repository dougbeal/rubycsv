#!/usr/bin/env ruby

require 'csv'
require 'erb'
require 'date'

#require 'pry'

# globals
$template_file = ARGV[0]
$csv_filename = ARGV[1]
$template_text = ""
$header_row = []

# evaluate the template in order to get the templates and other variables out
$erb_template = File.read($template_file)

$template_text = $erb_template


# class to bind hash into erb template
class CSVRow
    attr_accessor :csvrow

    def initialize(row)
        @csvrow = Hash.new
        index = 0
        $header_row.size.times do
            @csvrow[$header_row[index]] = row[index]
            index +=1;
        end
    end

    def get_binding()
        return binding()
    end
end

class LedgerFormatCSVRow < CSVRow
    def initialize(row)
        super(row)
        @ledger_indent = ' '*4
        @ledger_transaction = @ledger_indent + '%-23s  %23s'
        @ledger_tag = @ledger_indent + '; %s: %s'
    end
end


# helper functions
def clean_date(text_date, date_format="%Y-%m-%d") # reformat date in to big endian format
    return Date.strptime(text_date,date_format).strftime("%Y-%m-%d")
end

def clean_date_time(text_date, date_format="%Y-%m-%d %H:%M:%S") # reformat date in to big endian format
    return DateTime.strptime(text_date,date_format).strftime("%Y-%m-%d")
end

# clean money are return with $ for USD in ledger
def clean_money_usd(text_money, positive: false, invert: false)
    return "$" + clean_money(text_money, positive: positive, invert: invert)
end

def clean_money(text_money, positive: false, invert: false) # nuke all but digits, negation, decimal place
    if text_money.nil?
        return ""
    end

    if positive
        return text_money.gsub(/[^\d\.]/,'')
    elsif invert
        #num = text_money.gsub(/[^\d\.]/,'')
        num = text_money.gsub(/[^-\d\.]/,'')
        if num.start_with?('-')
            return num[1..]
        else
            return "-" + num
        end
    else
        return text_money.gsub(/[^-\d\.]/,'')
    end
end

def clean_num(text_num) # nuke all but digits, negation
    if text_num.nil?
        return ""
    end
    return text_num.gsub(/[^-\d]/,'')
end

def clean_text(text) # get rid of anything that's not a word or space, make multiple spaces single space
    if text.nil?
        return ""
    end
    return text.gsub(/[^\w \]\[\@\.\,\'\"]/,'').gsub(/[ ]+/,' ').strip;
end

# lookup values in arrays.  Table is a 2D array,
# where the first value is the string returned,
# and the following are substrings to attempt to match against the value

def tablematch(table, value)
    default = ""

    table.each do |row|
        rowfirst = row.first

        row.slice(1,row.length).each do |item|
            if item == "DEFAULT"  # set the default value
                default = rowfirst
            elsif value.match(/^#{item}/i)
                #print "  val: #{value} matches #{item}, returning #{rowfirst}\n"
                return rowfirst
            end
        end
    end
    return default
end

# parse CSV file

csv = CSV.open($csv_filename,'r', liberal_parsing: true)

csv.each() do |row|
    begin
        if(csv.lineno == 1) #this is the header row, store to assign as keys on later rows, stripping whitespace
            $header_row = row.collect{|val| val.to_s.strip}
        else
            thisrow = LedgerFormatCSVRow.new(row)
            #print "line: #{thisrow.csvrow.inspect}\n"
            erbrender = ERB.new($erb_template, safe_mode=nil, trim_mode='-<>')
            puts erbrender.result(thisrow.get_binding)
        end
    rescue => e
        STDERR.puts "'#{$template_file}'/'#{$csv_filename}':#{csv.lineno}"
        STDERR.puts "\t#{$header_row}"
        STDERR.puts "\t#{row}"
        STDERR.puts "\t#{thisrow.get_binding().source_location}"
        STDERR.puts "\t#{e}"
        e.backtrace.each { |l| STDERR.puts "\t#{l}" }
        raise e
    end
end


# Local Variables:
# ruby-indent-level: 4
# End:
