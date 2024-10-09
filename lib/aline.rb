require 'zlib'

module Aline
  VERSION = "0.0.1"

  autoload(:SequenceMatcher, 'aline/sequence_matcher')

  module Mapper
    def self.build_map_with_associated_data(lines, associated_data)
      unless lines.size == associated_data.size
        raise "lines count must match data count"
      end

      data = associated_data.map { |d| (d * 255).floor }
      data.each do |d|
        if d < 0 || d > 255
          raise "invalid data exceeds range of byte"
        end
      end
      result = String.new
      lines.zip(data).each do |line, datum|
        result << (Zlib::crc32(line)%256).chr
        result << datum.chr
      end
      result
    end

    def self.build_map_without_associated_data(lines)
      lines.map { |d| (Zlib::crc32(d)%256).chr }.join
    end
  end

  module Formatter
    def self.render_hunk(a, b, opcodes, a_data, b_lines)
      lines = []
      lines << opcodes.collect do |(code, a_start, a_end, b_start, b_end)|
        case code
        when :equal 
          a_segment = a_data[a_start..a_end]
          b_segment = b_lines[b_start..b_end]
          a_segment.zip(b_segment).map do |datum, line|
            "\x1b[48;2;#{datum};0;0m#{line}\x1b[0m"
          end
        when :insert
          b_lines[b_start..b_end]
        end
      end
      lines
    end
  end

  module Remapper
    class << self
      def remap(left_map, right_file)
        lmap = File.read(left_map)
        rlines = File.read(right_file, external_encoding: Encoding::BINARY).split("\n")

        rmap = Aline::Mapper.build_map_without_associated_data(rlines)

        diff_maps(lmap, rmap, rlines)
      end

      def diff_maps(lmap, rmap, rlines)
        ldata = lmap.unpack("C*").each_slice(2).to_a # [[crc8, datum], ...]
        rdata = rmap.unpack("C*") # [crc8, crc8, ...]
        diff_sequences(ldata.map(&:first), rdata, ldata.map(&:last), rlines)
      end

      def diff_sequences(left, right, data, right_lines)
        a = left
        b = right

        hunks = [Aline::SequenceMatcher.diff_opcodes(a, b)]

        return nil unless hunks.any?

        lines = []
        last_hunk_end = -1
        hunks.each do |opcodes|
          lines << Aline::Formatter.render_hunk(a, b, opcodes, data, right_lines)
          last_hunk_end = opcodes.last[4]
        end
        lines.flatten.compact.join("\n") + "\n"
      end
    end
  end
end
