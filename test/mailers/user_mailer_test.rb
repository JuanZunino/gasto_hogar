require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "welcome email has the correct recipient subject and safe personalized content" do
    user = User.create!(name: "Juan Zunino", email: "juan@example.com", password: "clave-privada")
    email = UserMailer.welcome_email(user)

    assert_equal [ user.email ], email.to
    assert_equal "Bienvenido a GastoHogar", email.subject
    assert_equal [ "no-reply@gastohogar.example" ], email.from
    assert email.multipart?
    [ email.text_part, email.html_part ].each do |part|
      assert_not_nil part
      body = part.body.decoded
      assert_includes body, user.name
      assert_includes body, "Bienvenido a GastoHogar"
      assert_includes body, "Tu cuenta fue creada correctamente."
      [ user.password, user.password_digest, "password", "password_digest", "token" ].each do |secret|
        assert_not_includes body, secret
      end
    end
  end
end
