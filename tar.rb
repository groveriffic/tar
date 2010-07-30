require 'stringio'

module Tar
  class Archive
    attr_reader :headers, :files

    # archive can be string of data, file path or IO object.

    def initialize(archive, options = {} )
      @archive = archive
      @options = options

      read_headers
      @files = @headers.map{ |header| File.new(self, header) }
    end

    def inspect
      "#<#{self.class}:0x#{hash.to_s(16)}>"
    end

    private
      def io
        @io ||= if @archive.is_a?(String) and @archive.size > 1024 then
          ::StringIO.new(@archive)
        elsif @archive.is_a?(String)
          ::File.open(@archive, 'r') 
        else
          @archive
        end
      end

      def read_headers
        @headers = Array.new
        while data = io.read(512)
          break if data.nil? or data.empty?
          h = Header.new(io.pos, data)
          if h.name.empty? then
            h = Header.new(io.pos + 512, io.read(512))
            break if h.name.empty?
            raise "Malformed header at position: #{io.pos - 1024}"
          end
          @headers << h
          p h.name
          if h.size > 0 then
            io.pos = io.pos + ((h.size / 512.0).ceil * 512)
          end
        end
      end
  end

  class File
    attr_reader :header
    def initialize(archive, header)
      @archive = archive
      @header = header
    end

    def read
      io = @archive.instance_eval { @io }
      io.pos = header.pos
      io.read( header.size )
    end

    def inspect
      "#<#{self.class}:0x#{hash.to_s(16)} name=#{name}>"
    end

    def name
      header.name
    end
  end

  class Header
# Found header format documentation at:
# http://www.gnu.org/software/automake/manual/tar/Standard.html
    attr_reader :pos

    def initialize(pos = 0, data = '')
      @data = data
      @pos = pos
    end

    def name
      nt(@data[0,100])
    end
    def mode
      @data[100,8].oct
    end
    def uid
      @data[108,8].oct
    end
    def gid
      @data[116,8].oct
    end
    def size
      @data[124,12].oct
    end
    def mtime
      @data[136,12].oct
    end
    def chksum
      @data[148,8].oct
    end
    def typeflag
      @data[156,1].oct
    end
    def linkname
      nt(@data[157,100])
    end
    def magic
      nt(@data[257,6])
    end
    def version
      @data[263,2].oct
    end
    def uname
      nt(@data[265,32])
    end
    def gname
      nt(@data[297,32])
    end
    def devmajor
      @data[329,8].oct
    end
    def devminor
      @data[337,8].oct
    end
    def prefix
      @data[345,155].oct
    end

    private
      def null_terminated(value)
        value[0,value.index("\x00")]
      end
      alias :nt :null_terminated
  end

end
