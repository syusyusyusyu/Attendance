namespace :attendance do
  desc "Finalize attendance for past sessions"
  task finalize: :environment do
    AttendanceFinalizer.finalize_all!
  end
end
