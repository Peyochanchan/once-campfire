require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "settings" do
    accounts(:signal).restrict_room_creation_to_administrators = true
    assert accounts(:signal).restrict_room_creation_to_administrators?
    assert_equal({ "restrict_room_creation_to_administrators" => true }, accounts(:signal)[:settings])

    accounts(:signal).update!(settings: { "restrict_room_creation_to_administrators" => "true" })
    assert accounts(:signal).reload.restrict_room_creation_to_administrators?

    accounts(:signal).restrict_room_creation_to_administrators = false
    assert_not accounts(:signal).restrict_room_creation_to_administrators?
    assert_equal({ "restrict_room_creation_to_administrators" => false }, accounts(:signal)[:settings])
    accounts(:signal).update!(settings: { "restrict_room_creation_to_administrators" => "false" })
    assert_not accounts(:signal).reload.restrict_room_creation_to_administrators?
  end

  test "default settings" do
    a = Account.create! name: "New account"
    assert_equal({ "restrict_room_creation_to_administrators" => false }, a[:settings])
  end
end
