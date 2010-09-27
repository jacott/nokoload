module Nokoload
  class Runner
    class FormData
      attr_reader :form_data, :form_files

      def initialize(form_data,form=nil)
        @form_data=form_data
        @form_files={}
        @form=form
      end

      def add_form
        @form.css("input").each do |input|
          unless input['disabled'] || input['type'].to_s.casecmp('submit')==0
            if input['type'].to_s.casecmp('file')==0
              form_files[input['name'].to_s]=input['value'].to_s
            elsif input['type'].to_s.casecmp('checkbox') == 0
              if input['checked'].to_s.casecmp('checked') == 0
                add_param(input['name'].to_s,input['value'].to_s)
              end
            else
              add_param(input['name'].to_s,input['value'].to_s)
            end
          end
        end
        @form.css("select").each { |select| add_param(select['name'].to_s,get_select_value(select)) unless select['disabled']}
        self
      end

      def get_select_value(select)
        (option=select.css("option[selected=selected]").first) &&
          (v=option['value'].to_s).empty? ? nil : v
      end

      def fill_values_by_labels(fields)
        fields.each do |k,v|
          v=v.to_s
          raise "can't find label '#{k}'" unless label=@form.css("label").find {|e| e.content.strip == k }
          if field=(@form.css("input##{label['for']}").first || @form.css("textarea##{label['for']}").first)
            if field['type'].to_s.casecmp('checkbox') == 0
              @form.css(css="input[name=\"#{field['name']}\"]").each do |e|
                if field['value'] == v
                  field['checked']= 'checked'
                else
                  field.remove_attribute('checked')
                end
              end
            else
              field['value']=v
            end
          elsif field=@form.css("select##{label['for']}").first
            raise "can't find corresponding option '#{v}' for select of label '#{k}'" unless option=field.css("option").find { |e| e.content.strip == v }
            (selected=field.css("option[selected=selected]").first) && selected.remove_attribute('selected')
            option['selected']='selected'
          else
            raise "can't find corresponding field for label '#{k}'. ID=#{label['for']}"
          end
        end
        self
      end

      def to_s
        @form_data.inspect
      end

      def to_params(sep='&')
        @form_data.map do |k, v|
          encode_kvpair(k, v)
        end.flatten.join(sep)
      end

      def each_param(&block)
        @form_data.each do |k,v|
          encode_multi_kvpair(k,v,&block)
        end
      end

      def add_param(name,value)
        parts=name.gsub(']','').split('[',-1)
        set_part(@form_data,parts[0],parts[1..-1],value)
      end

      def set_part(result,car,cdr,value)
        if cdr.empty?
          if Array === result
            result << {} unless Hash === (sub=result.last) && !sub.include?(car)
            result = result.last
          end
          result[car]=value
        elsif cdr[0] == ''
          if sub=result[car]
            raise InvalidArgument, "#{sub.class} is not an Array" unless Array === sub
          else
            sub=result[car]=[]
          end
          if cdr.size == 1
            sub << value
          else
            set_part(sub,cdr[1],cdr[2..-1],value)
          end
        else
          if sub=result[car]
            raise InvalidArgument, "#{sub.class} is not a Hash" unless Hash === sub
          else
            sub=result[car]={}
          end
          set_part(sub,cdr[0],cdr[1..-1],value)
        end
      end

      def encode_multi_kvpair(key, v, parent_key=nil, &block)
        key="#{parent_key}[#{key}]" if parent_key
        case v
        when Hash
          v.each do |k, v|
            encode_multi_kvpair(k, v, key, &block)
          end
        when Array
          v.each {|v| encode_multi_kvpair(nil, v, key, &block) }
        else
          block.call urlencode(key), v
        end
      end

      def encode_kvpair(key, v, parent_key=nil)
        key="#{parent_key}[#{key}]" if parent_key
        case v
        when Hash
          v.map do |k, v|
            encode_kvpair(k, v, key)
          end
        when Array
          v.map {|v| encode_kvpair(nil, v, key) }
        else
          "#{urlencode(key)}=#{urlencode(v.to_s)}"
        end
      end
      private :encode_kvpair

      if RUBY_VERSION =~ /^1\.8/
        def urlencode(str)
          str.to_s.dup.gsub(/[^\[\]a-zA-Z0-9_\.\-]/){'%%%02x' % $&.ord}
        end
      else
        def urlencode(str)
          str.to_s.dup.force_encoding('ASCII-8BIT').gsub(/[^\[\]a-zA-Z0-9_\.\-]/){'%%%02x' % $&.ord}
        end
      end
      private :urlencode
    end
  end
end
