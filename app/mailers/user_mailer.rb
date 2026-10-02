class UserMailer < ApplicationMailer
  default from: "GastoHogar <no-reply@gastohogar.example>"

  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Bienvenido a GastoHogar")
  end
end
