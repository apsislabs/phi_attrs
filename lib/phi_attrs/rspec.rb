require 'rspec/expectations'

RSpec::Matchers.define :to_allow_phi_access do
  match_for_should do |result|
    @allowed = result.allow_phi?
    @user_id_matches = @user_id.nil? || @user_id == result.phi_allowed_by
    @reason_matches = @reason.nil? || @reason == result.phi_access_reason

    @allowed && @user_id_matches && @reason_matches
  end

  match_for_should_not do |result|
    @disallowed = !result.allow_phi?
    @user_id_does_not_match = @user_id.nil? || @user_id != result.phi_allowed_by
    @reason_does_not_match = @reason.nil? || @reason != result.phi_access_reason

    @disallowed && @user_id_does_not_match && @reason_does_not_match
  end

  chain :allowed_by do |user_id|
    @user_id = user_id
  end

  chain :with_access_reason do |reason|
    @reason = reason
  end

  # :nocov:
  failure_message do |result|
    expected = ['Expected phi to be allowed']
    expected << "by user: \"#{@user_id}\"" unless @user_id.nil?
    expected << "for reason: \"#{@reason}\"" unless @reason.nil?
    expected = "#{expected.join ' '}."

    failure_reason = ['But']
    failure_reason << 'it was not allowed' unless @allowed
    failure_reason << "it was allowed by #{@result.phi_allowed_by}" unless @user_id_matches
    failure_reason << "it was allowed because #{@result.phi_access_reason}" unless @reason_amtches
    failure_reason = "#{failure_reason.join ', and '}."

    [ expected, failure_reason ].join " "
  end

  failure_message_when_negated do |result|
    expected = ['Did not expect phi to be allowed']
    expected << "by user: \"#{@user_id}\"" unless @user_id.nil?
    expected << "for reason: \"#{@reason}\"" unless @reason.nil?
    expected = "#{expected.join ' '}."

    failure_reason = ['But']
    failure_reason << 'it was allowed' unless @disallowed
    failure_reason << "it was allowed by #{@result.phi_allowed_by}" unless @user_id_does_not_match
    failure_reason << "it was allowed because #{@result.phi_access_reason}" unless @reason_does_not_match
    failure_reason = "#{failure_reason.join ', and '}."

    [ expected, failure_reason ].join " "
  end
  # :nocov:
end
