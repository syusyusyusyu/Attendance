class OperationRequestProcessor
  HANDLERS = {
    "attendance_correction" => OperationRequestHandlers::AttendanceCorrection,
    "attendance_finalize" => OperationRequestHandlers::AttendanceFinalize,
    "attendance_unlock" => OperationRequestHandlers::AttendanceUnlock,
    "attendance_csv_import" => OperationRequestHandlers::AttendanceCsvImport
  }.freeze

  def initialize(operation_request:, processed_by:, ip:, user_agent:)
    @operation_request = operation_request
    @processed_by = processed_by
    @ip = ip
    @user_agent = user_agent
  end

  def approve!
    handler_class = HANDLERS.fetch(operation_request.kind) do
      raise ArgumentError, "未対応の申請種別です"
    end

    handler_class.new(
      operation_request: operation_request,
      processed_by: processed_by,
      ip: ip,
      user_agent: user_agent
    ).call
  end

  private

  attr_reader :operation_request, :processed_by, :ip, :user_agent
end
