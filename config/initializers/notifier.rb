Rails.configuration.middleware.use ExceptionNotification::Rack, email: {
  email_prefix: "[ELMO ERROR] ",
  sender_address: configatron.site_email,
  exception_recipients: configatron.webmaster_emails,

  # Not including session because it contains user_credentials, not sure if that's secret,
  # and adding it to the filter did not work.
  sections: %w(request environment backtrace)
}