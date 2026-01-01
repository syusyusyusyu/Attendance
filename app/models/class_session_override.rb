class ClassSessionOverride < ApplicationRecord
  belongs_to :school_class

  enum :status, {
    regular: "regular",
    makeup: "makeup",
    canceled: "canceled"
  }, prefix: true

  validates :date, presence: true
  validate :time_pair_consistency

  private

  def time_pair_consistency
    return if start_time.blank? && end_time.blank?

    if start_time.blank? || end_time.blank?
      errors.add(:base, "開始時刻と終了時刻はセットで入力してください")
    end
  end
end
