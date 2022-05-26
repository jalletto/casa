class CaseContactTypesReminder
  def send!
    # TODO: add condition so they are only notified one per quarter
    eligible_volunteers = User.where(type: Volunteer, receive_sms_notifications: true).where.not(phone_number: nil)
    eligible_volunteers.each do |volunteer|
      next if last_reminder_within_quarter(volunteer)
      uncontacted_case_contact_types = uncontacted_case_types(volunteer)
      send_sms_messages(volunteer, uncontacted_case_contact_types)
      update_reminder_sent_time(volunteer)
    end
  end

  private

  def uncontacted_case_contact_types(volunteer)
    contacted_types = volunteer.case_contacts.where("occured_at < ?", 2.months.ago).joins(:contact_types).pluck(:name)
    ContactType.all.pluck(:name).uniq - contacted_types
  end

  def send_sms_messages(volunteer, uncontacted_case_contact_types)
    volunteer_casa_org = volunteer.casa_org
    if !valid_casa_twilio_creds(volunteer_casa_org)
      return
    end

    twilio_service = TwilioService.new(volunteer_casa_org.twilio_api_key_sid, volunteer_casa_org.twilio_api_key_secret, volunteer.twilio_account_sid)
    sms_params = {
      From: volunteer_casa_org.twilio_phone_number,
      Body: nil,
      To: volunteer.phone_number
    }

    messages = [
      ["It's been 60 days or more since you've reached out to these members of your youth's network:"],
      [uncontacted_case_contact_types],
      ["If you have made contact with them in the past 60 days, remember to log it: [link to create new case contact for assigned case]"]
    ]

    messages.each do |contents|
      sms_params.Body = contents.join("\n")
      twilio_service.send_sms(sms_params)
    end


  end

  def valid_casa_twilio_creds(casa_org)
    casa_org.twilio_phone_number? && casa_org.twilio_account_sid? && casa_org.twilio_api_key_sid? && casa_org.twilio_api_key_secret?
  end

  def last_reminder_within_quarter(volunteer)
    reminder = UserCaseContactTypesReminder.find_by(user_id: volunteer.id)

    if reminder?
      return reminder.reminder_sent < 3.months.ago
    end

    false
  end

  def update_reminder_sent_time(volunteer)
    reminder = UserCaseContactTypesReminder.find_by(user_id: volunteer.id)

    if reminder?
        reminder.reminder_sent = DateTime.now
    else
        reminder = UserCaseContactTypesReminder.new(user_id: volunteer.id, reminder_sent: DateTime.now)
    end

    reminder.save
  end
end
