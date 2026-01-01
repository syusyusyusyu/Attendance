class Admin::OperationRequestsController < Admin::BaseController
  before_action -> { require_permission!("admin.operation.approve") }

  def index
    @status = params[:status].presence
    @kind = params[:kind].presence

    scope = OperationRequest.includes(:user, :school_class, :processed_by).order(created_at: :desc)
    scope = scope.where(status: @status) if @status
    scope = scope.where(kind: @kind) if @kind

    @requests = scope.limit(200)
  end

  def update
    operation_request = OperationRequest.find(params[:id])

    if operation_request.status != "pending"
      redirect_to admin_operation_requests_path, alert: "この申請は処理済みです。" and return
    end

    decision = params[:decision].to_s
    decision_reason = params[:decision_reason]

    if decision == "approve"
      kind_label = kind_label_for(operation_request.kind)
      OperationRequest.transaction do
        OperationRequestProcessor.new(
          operation_request: operation_request,
          processed_by: current_user,
          ip: request.remote_ip,
          user_agent: request.user_agent
        ).approve!

        operation_request.update!(
          status: "approved",
          processed_by: current_user,
          processed_at: Time.current,
          decision_reason: decision_reason
        )
      end

      Notification.create!(
        user: operation_request.user,
        kind: "info",
        title: "操作申請が承認されました",
        body: "#{kind_label} の承認が完了しました。",
        action_path: admin_operation_requests_path
      )
      redirect_to admin_operation_requests_path, notice: "申請を承認しました。"
    elsif decision == "reject"
      kind_label = kind_label_for(operation_request.kind)
      operation_request.update!(
        status: "rejected",
        processed_by: current_user,
        processed_at: Time.current,
        decision_reason: decision_reason
      )

      Notification.create!(
        user: operation_request.user,
        kind: "warning",
        title: "操作申請が却下されました",
        body: "#{kind_label} の申請が却下されました。",
        action_path: admin_operation_requests_path
      )
      redirect_to admin_operation_requests_path, notice: "申請を却下しました。"
    else
      redirect_to admin_operation_requests_path, alert: "操作が不正です。"
    end
  rescue StandardError => e
    redirect_to admin_operation_requests_path, alert: "承認処理に失敗しました: #{e.message}"
  end

  private

  def kind_label_for(kind)
    {
      "attendance_correction" => "出席修正",
      "attendance_finalize" => "出席確定",
      "attendance_unlock" => "確定解除",
      "attendance_csv_import" => "CSV反映"
    }[kind] || kind
  end
end
