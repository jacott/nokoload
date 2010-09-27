module Nokoload
  class StreamPart
    def initialize( stream, size )
      @stream, @size = stream, size
    end

    def size
      @size
    end

    def read ( offset, how_much )
      @stream.read ( how_much )
    end
  end

  class StringPart
    def initialize ( str )
      @str = str
    end

    def size
      @str.length
    end

    def read ( offset, how_much )
      @str[offset, how_much]
    end
  end

  class MultipartStream
    def initialize( parts )
      @parts = parts
      @part_no = @part_offset = 0
    end

    def size
      @parts.inject(0) { |total,part| total += part.size }
    end

    def read ( how_much )
      return nil if @part_no >= @parts.size

      how_much_current_part = @parts[@part_no].size - @part_offset

      how_much_current_part = how_much_current_part > how_much ? how_much : how_much_current_part

      how_much_next_part = how_much - how_much_current_part

      current_part = @parts[@part_no].read(@part_offset, how_much_current_part )

      if how_much_next_part > 0
        @part_no += 1
        @part_offset = 0
        next_part = read ( how_much_next_part  )
        current_part + (next_part || '')
      else
        @part_offset += how_much_current_part
        current_part
      end
    end
  end
end
