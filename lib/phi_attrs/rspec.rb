require 'rspec/expectations'

DO_NOT_SPECIFY = "do not specify `allowed_by` or `with_access_reason` for negated `allow_phi_access`"

RSpec::Matchers.define :allow_phi_access do
  match do |result|
    @allowed = result.phi_allowed?
    @user_id_matches = @user_id.nil? || @user_id == result.phi_allowed_by
    @reason_matches = @reason.nil? || @reason == result.phi_access_reason

    @allowed && @user_id_matches && @reason_matches
  end

  match_when_negated do |result|
    raise ArgumentError, DO_NOT_SPECIFY unless @user_id.nil? && @reason.nil?

    !result.phi_allowed?
  end

  chain :allowed_by do |user_id|
    @user_id = user_id
  end

  chain :with_access_reason do |reason|
    @reason = reason
  end

  # :nocov:
  failure_message do |result|
    msgs = []

    msgs = ['PHI Access was not allowed.'] unless @allowed
    msgs << "PHI Access was allowed by '#{result.phi_allowed_by}' (not '#{@user_id}')." unless @user_id_matches
    msgs << "PHI Access was allowed because '#{result.phi_access_reason}' (not because '#{@reason}')." unless @reason_matches

    msgs.join "\n"
  end

  failure_message_when_negated do |result|
    "PHI access was allowed by '#{result.phi_allowed_by}', because '#{result.phi_access_reason}'"
  end
  # :nocov:
end
