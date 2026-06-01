class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.roastnode.mail_from_address }
  layout "mailer"
end
