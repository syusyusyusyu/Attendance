class Admin::OperationRequestsController < Admin::BaseController
  before_action -> { require_permission!("admin.operation.approve") }

  def index
    stored = session[:admin_operation_requests_last_filter].is_a?(Hash) ? session[:admin_operation_requests_last_filter] : {}
    @status =
      if params.key?(:status)
        params[:status].presence
      else
        stored["status"].presence
      end
    @kind =
      if params.key?(:kind)
        params[:kind].presence
      else
        stored["kind"].presence
      end
    session[:admin_operation_requests_last_filter] = { "status" => @status, "kind" => @kind }.compact_blank

    scope = OperationRequest.includes(:user, :school_class, :processed_by).order(created_at: :desc)
    scope = scope.where(status: @status) if @status
    scope = scope.where(kind: @kind) if @kind

    @requests = scope.limit(200)
  end

  def update
    @operation_request = OperationRequest.includes(:user, :school_class, :processed_by).find(params[:id])

    if @operation_request.status != "pending"
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "この申請は処理済みです。"
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash"), status: :unprocessable_entity
        end
        format.html do
          redirect_to admin_operation_requests_path, alert: "この申請は処理済みです。"
        end
      end
      return
    end

    decision = params[:decision].to_s
    decision_reason = params[:decision_reason]

    if decision == "approve"
      kind_label = kind_label_for(@operation_request.kind)
      OperationRequest.transaction do
        OperationRequestProcessor.new(
          operation_request: @operation_request,
          processed_by: current_user,
          ip: request.remote_ip,
          user_agent: request.user_agent
        ).approve!

        @operation_request.update!(
          status: "approved",
          processed_by: current_user,
          processed_at: Time.current,
          decision_reason: decision_reason
        )
      end

      Notification.create!(
        user: @operation_request.user,
        kind: "info",
        title: "操作申請が承認されました",
        body: "#{kind_label} の承認が完了しました。",
        action_path: admin_operation_requests_path
      )
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "申請を承認しました。" }
        format.html { redirect_to admin_operation_requests_path, notice: "申請を承認しました。" }
      end
    elsif decision == "reject"
      kind_label = kind_label_for(@operation_request.kind)
      @operation_request.update!(
        status: "rejected",
        processed_by: current_user,
        processed_at: Time.current,
        decision_reason: decision_reason
      )

      Notification.create!(
        user: @operation_request.user,
        kind: "warning",
        title: "操作申請が却下されました",
        body: "#{kind_label} の申請が却下されました。",
        action_path: admin_operation_requests_path
      )
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "申請を却下しました。" }
        format.html { redirect_to admin_operation_requests_path, notice: "申請を却下しました。" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "操作が不正です。"
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash"), status: :unprocessable_entity
        end
        format.html do
          redirect_to admin_operation_requests_path, alert: "操作が不正です。"
        end
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "承認処理に失敗しました。"
        render turbo_stream: turbo_stream.update("flash", partial: "shared/flash"), status: :unprocessable_entity
      end
      format.html do
        redirect_to admin_operation_requests_path, alert: "承認処理に失敗しました: #{e.message}"
      end
    end
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
