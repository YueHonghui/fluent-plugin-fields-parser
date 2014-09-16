module Fluent
  class OutputFieldsParser < Fluent::Output
    Fluent::Plugin.register_output('fields_parser', self)

    config_param :remove_tag_prefix,  :string, :default => nil
    config_param :add_tag_prefix,     :string, :default => nil
    config_param :parse_key,          :string, :default => 'message'
    config_param :pattern,            :string,
                 :default => %{([a-zA-Z_]\\w*)=((['"]).*?(\\3)|[\\w.@$%/+-]*)}

    def compiled_pattern
      @compiled_pattern ||= Regexp.new(pattern)
    end

    def emit(tag, es, chain)
      tag = update_tag(tag)
      es.each { |time, record|
        target = {}
        source = record[parse_key].to_s
        begin
          target = parse_fields(source)
        rescue ArgumentError => e
          raise e unless e.message.index("invalid byte sequence in") == 0
          source = source.encode('UTF-8', 'GB18030', :invalid => :replace, :undef => :replace, :replace => '?')
          target = parse_fields(source)
        end
        Engine.emit(tag, time, target)
      }
      chain.next
    end

    def update_tag(tag)
      if remove_tag_prefix
        if remove_tag_prefix == tag
          tag = ''
        elsif tag.to_s.start_with?(remove_tag_prefix+'.')
          tag = tag[remove_tag_prefix.length+1 .. -1]
        end
      end
      if add_tag_prefix
        tag = tag && tag.length > 0 ? "#{add_tag_prefix}.#{tag}" : add_tag_prefix
      end
      return tag
    end

    def parse_fields(source)
      target = {}

      source.scan(compiled_pattern) do |match|
        (key, value, begining_quote, ending_quote) = match
        next if key.nil?
        next if target.has_key?(key)
        value = value.to_s
        from_pos = begining_quote.to_s.length
        to_pos = value.length - ending_quote.to_s.length - 1
        target[key] = value[from_pos..to_pos]
      end
      return target
    end
  end
end
