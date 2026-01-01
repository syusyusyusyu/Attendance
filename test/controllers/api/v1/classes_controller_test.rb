require "test_helper"

class Api::V1::ClassesControllerTest < ActionDispatch::IntegrationTest
  test "requires api key" do
    get "/api/v1/classes"
    assert_response :unauthorized
  end

  test "rejects missing scope" do
    admin = User.create!(
      email: "api-admin@example.com",
      name: "APIŠÇ—Ò",
      role: "admin",
      password: "password",
      password_confirmation: "password"
    )

    _key, token = ApiKey.generate!(user: admin, name: "no-scope", scopes: ["attendance:read"])
    get "/api/v1/classes", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :forbidden
  end

  test "returns classes with valid scope" do
    admin = User.create!(
      email: "api-admin2@example.com",
      name: "APIŠÇ—Ò2",
      role: "admin",
      password: "password",
      password_confirmation: "password"
    )
    teacher = User.create!(
      email: "api-teacher@example.com",
      name: "’S“–‹³ˆõ",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    SchoolClass.create!(
      name: "API‰‰K",
      teacher: teacher,
      room: "6A‹³º",
      subject: "î•ñ",
      semester: "‘OŠú",
      year: 2024,
      capacity: 35,
      schedule: { day_of_week: 2, start_time: "10:50", end_time: "12:20" }
    )

    _key, token = ApiKey.generate!(user: admin, name: "read-classes", scopes: ["classes:read"])
    get "/api/v1/classes", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal 1, body.size
    assert_equal "API‰‰K", body.first.fetch("name")
  end
end
