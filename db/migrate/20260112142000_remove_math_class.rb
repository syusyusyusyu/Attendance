class RemoveMathClass < ActiveRecord::Migration[8.0]
  def up
    names = ["数学I", "数学1", "数学１"]
    SchoolClass.where(name: names).find_each do |klass|
      AttendancePolicy.where(school_class_id: klass.id).delete_all
      AttendanceRecord.where(school_class_id: klass.id).delete_all
      AttendanceRequest.where(school_class_id: klass.id).delete_all
      ClassSession.where(school_class_id: klass.id).delete_all
      ClassSessionOverride.where(school_class_id: klass.id).delete_all
      Enrollment.where(school_class_id: klass.id).delete_all
      QRSession.where(school_class_id: klass.id).delete_all
      QRScanEvent.where(school_class_id: klass.id).delete_all
      OperationRequest.where(school_class_id: klass.id).delete_all
      klass.destroy!
    end
  end

  def down
    # no-op (数学Iは再生成しない)
  end
end
