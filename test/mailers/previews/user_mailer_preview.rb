class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    user = User.new(name: "Juan Zunino", email: "juan@example.com")
    UserMailer.welcome_email(user)
  end
end
