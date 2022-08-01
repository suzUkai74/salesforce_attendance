require 'selenium-webdriver'
require 'yaml'
require 'pry'
require 'active_support/time'

LOGIN_URL         = 'https://login.salesforce.com/'
NEW_LOGIN_URL     = 'https://d10000000azraea2.my.salesforce.com/'
KINTAI_LINK_ID    = '01r5F000000QZBV_Tab'
BASE_START_ID     = 'ttvTimeSt'
INPUT_DIALOG_ID   = 'dijit_DialogUnderlay_0'
PREV_MONTH_BTN_ID = 'prevMonthButton'

config       = YAML.load_file('config.yml')
profile_path = config.key?('chrome_profile') ? config['chrome_profile'] : './chrome_profile'
caps         = Selenium::WebDriver::Remote::Capabilities.chrome(
  chromeOptions: {
    args: ["--user-data-dir=#{profile_path}"]
  }
)
driver     = Selenium::WebDriver.for(:chrome, desired_capabilities: caps)
today      = Date.today
start_date = Date.new(today.year, today.month, 1) - 1.month
end_date   = start_date.end_of_month
driver.navigate.to(NEW_LOGIN_URL)
username_input = driver.find_element(:id, 'username')
pw_input = driver.find_element(:id, 'password')
username_input.send_keys(config['username'])
pw_input.send_keys(config['password'])

begin
  driver.find_element(:id, 'Login').click
  wait = Selenium::WebDriver::Wait.new(timeout: 30)
  wait.until { driver.title.start_with?('Salesforce') }
  puts('Login success.')
rescue
  puts('Login failed.')
  driver.quit
end

driver.find_element(:id, KINTAI_LINK_ID).click
wait = Selenium::WebDriver::Wait.new(timeout: 10)
wait.until { driver.find_element(:id, PREV_MONTH_BTN_ID).displayed? }

btn_div_element = driver.find_element(:id, PREV_MONTH_BTN_ID)
btn_div_element.find_element(:xpath, '..').click
wait = Selenium::WebDriver::Wait.new(timeout: 10)
wait.until { !driver.find_element(:id, 'shim').displayed? }

(start_date..end_date).each do |date|
  begin
    puts(date)
    driver.find_element(:id, "#{BASE_START_ID}#{date}").click
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    wait.until { driver.find_element(:id, INPUT_DIALOG_ID).displayed? }
    st_input = driver.find_element(:id, 'startTime')
    et_input = driver.find_element(:id, 'endTime')
    time_submit = driver.find_element(:id, 'dlgInpTimeOk')
    st_input.clear
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    wait.until { st_input.text.blank? }
    sleep 0.5 # wait until inputable st_input
    st_input.send_keys(config['start_time'])
    et_input.clear
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    wait.until { et_input.text.blank? }
    et_input.send_keys(config['end_time'])
    time_submit.click
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    wait.until { !driver.find_element(:id, INPUT_DIALOG_ID).displayed? }
  rescue
  end
end
