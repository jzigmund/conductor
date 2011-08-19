Feature: Manage Catalog Entries
  In order to manage catalog entries
  As an admin
  I want to add/edit/remove catalog entries

  Background:
    Given I am an authorised user
    And I am logged in

  Scenario: Create new catalog entry
    Given I am on the catalog entries page
    And there is a "default" catalog
    When I follow "new_catalog_entry_button"
    Then I should see "Add New Catalog Entry"
    When I fill in "catalog_entry[name]" with "test1"
    When I select "default" from "catalog_entry[catalog_id]"
    When I fill in "catalog_entry[description]" with "description"
    When I fill in "catalog_entry[url]" with "http://random_url"
    And I press "save_button"
    Then I should see "Catalog entry added"

  Scenario: Change the name
    Given a catalog entry "testdepl" exists
    And I am on the catalog entries page
    When I follow "testdepl"
    And I follow "edit_button"
    Then I should see "Editing Catalog Entry"
    When I fill in "catalog_entry[name]" with "testdepl-renamed"
    And I press "save_button"
    Then I should see "Catalog entry updated successfully!"
    And I should see "testdepl-renamed"

  Scenario: Show catalog entry details
    Given a catalog entry "testdepl" exists
    And I am on the catalog entries page
    When I follow "testdepl"
    Then I should see "testdepl"
    And I should see "Name"
    And I should see "description"
    And I should see "url"

  Scenario: Delete deployables
    Given a catalog entry "testdepl1" exists
    And a catalog entry "testdepl2" exists
    And I am on the catalog entries page
    When I check "testdepl1" catalog entry
    And I check "testdepl2" catalog entry
    And I press "delete_button"
    Then there should be only 0 catalog entries
    And I should be on the catalog entries page
    And I should not see "testdepl1"
    And I should not see "testdepl2"

  Scenario: Delete deployable
    Given a catalog entry "testdepl1" exists
    And I am on the catalog entries page
    When I follow "testdepl1"
    And I press "delete_button"
    Then there should be only 0 catalog entries
    And I should be on the catalog entries page
    And I should not see "testdepl1"
