#!/usr/bin/env ruby


#
#  PDF concatenator script - with a horrible but effective kludge which
#  ensures the final PDF only includes one copy of internal resources
#  (like fonts/images) which are duplicated across the input PDF files.
#
#  Generates smaller input if you first combine the input PDF files using 
#  "pdftk cat", for some reason.
#
#  (Written out of necessity after I once had to upload a concatenation
#  of 71 separate PDFs which contained the same 170K logo JPEG 71 times
#  over - no wonder it kept violating the site's upload size limit...)
#
#  Requires the CombinePDF library: gem install combine_pdf
#


require 'combine_pdf'


def local_only(x)
    if x.is_a?(Hash) && x[:is_reference_only] && x.has_key?(:indirect_reference_id) && x.has_key?(:indirect_generation_number)
        return { 
            :is_reference_only => true,
            :indirect_reference_id => x[:indirect_reference_id],
            :indirect_generation_number => x[:indirect_generation_number]
        }
    end
    if x.is_a?(Hash)
        return Hash[x.each_pair.collect{|k,v| [k,local_only(v)] }]
    elsif x.is_a?(Array)
        return x.collect{|xx| local_only(xx) }
    else
        return x
    end
end

def dedup_refs(x,dups={})
    if x.is_a?(Hash)
        if x[:is_reference_only] && x.has_key?(:indirect_reference_id) && x.has_key?(:indirect_generation_number)
            return dups[x[:indirect_reference_id]] if dups.has_key?(x[:indirect_reference_id])
            xx = dedup_refs(x[:referenced_object], dups)
            xx_local = local_only(xx)
            return dups[xx_local] if dups.has_key?(xx_local)
            result = {
                :is_reference_only => true,
                :referenced_object => xx,
                :indirect_reference_id => x[:indirect_reference_id],
                :indirect_generation_number => x[:indirect_generation_number]
            }
            dups[xx_local] = result
            dups[x[:indirect_reference_id]] = result
            return result
        else
            return Hash[x.each_pair.collect{|k,v| [k, (k == :Parent) ? v : dedup_refs(v, dups)] }]
        end
    elsif x.is_a?(Array)
        return x.collect{|xx| dedup_refs(xx, dups) }
    else
        return x
    end
end

output_pdf = CombinePDF.new
output_filename = ARGV.pop
dups = {}
#ARGV.each{|input_filename| CombinePDF.load(input_filename).pages.each {|p| output_pdf << dedup_refs(p, dups) } }
ARGV.each{|input_filename| CombinePDF.load(input_filename).pages.each {|p| output_pdf << p } }
output_pdf.save('/dev/null')
output_pdf.objects.collect!{|x| dedup_refs(x, dups) }
output_pdf.save(output_filename)
