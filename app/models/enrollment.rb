class Enrollment < ApplicationRecord
  belongs_to :school_class
  belongs_to :student, class_name: "User"

  validates :student_id, uniqueness: { scope: :school_class_id }
end
