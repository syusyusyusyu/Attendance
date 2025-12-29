class SchoolClass < ApplicationRecord
  belongs_to :teacher, class_name: "User"

  has_many :enrollments, dependent: :destroy
  has_many :students, through: :enrollments, source: :student
  has_many :attendance_records, dependent: :destroy

  validates :name, :room, :subject, :semester, :year, :capacity, presence: true
end
