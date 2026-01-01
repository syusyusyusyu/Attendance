require "csv"

class BaseCsvImporter
  def initialize(csv_text:)
    @csv_text = csv_text
  end

  private

  def each_row
    CSV.parse(sanitized_csv_text, headers: true).each_with_index do |row, index|
      line_no = index + 2
      yield row, line_no
    end
  end

  def cell_value(row, *keys)
    keys.each do |key|
      value = row[key]
      return value unless value.nil?
    end
    nil
  end

  def sanitized_csv_text
    @csv_text.to_s.sub(/\A\uFEFF/, "")
  end
end
