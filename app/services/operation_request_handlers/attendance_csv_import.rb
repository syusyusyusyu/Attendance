module OperationRequestHandlers
  class AttendanceCsvImport < Base
    def call
      csv_text = payload["csv_text"] || payload[:csv_text]
      raise ArgumentError, "CSVデータが空です" if csv_text.blank?

      AttendanceCsvImporter.new(
        teacher: processed_by,
        school_class: school_class,
        csv_text: csv_text
      ).import
    end
  end
end
