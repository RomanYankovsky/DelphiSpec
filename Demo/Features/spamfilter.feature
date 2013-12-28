Feature: Spam Filter

Scenario: Blacklist
  Given I have a blacklist:
      """
      m@mail.com
      123@mail.com
      """
    And I have empty inbox
  When I receive an email from "m@mail.com"
  Then my inbox is empty