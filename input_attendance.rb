require 'selenium-webdriver'
require 'yaml'
require 'pry'
require 'active_support/time'

KINTAI_LINK_CLASS  = 'wt-勤務表'.freeze
BASE_START_ID      = 'ttvTimeSt'.freeze
INPUT_DIALOG_ID    = 'dijit_DialogUnderlay_0'.freeze
YEAR_MONTH_LIST_ID = 'yearMonthList'.freeze

config       = YAML.load_file('config.yml')
profile_path = config.key?('chrome_profile') ? config['chrome_profile'] : './chrome_profile'
caps         = Selenium::WebDriver::Remote::Capabilities.chrome(
  chromeOptions: {
    args: ["--user-data-dir=#{profile_path}"]
  }
)
driver     = Selenium::WebDriver.for(:chrome, desired_capabilities: caps)
today      = Date.today
start_date = ARGV[0].blank? ? (Date.new(today.year, today.month, 1) - 1.month) : Date.parse(ARGV[0]).beginning_of_month
end_date   = start_date.end_of_month
driver.navigate.to(config['login_url'])
username_input = driver.find_element(:id, 'username')
pw_input = driver.find_element(:id, 'password')
username_input.send_keys(config['username'])
pw_input.send_keys(config['password'])

begin
  driver.find_element(:id, 'Login').click
  wait = Selenium::WebDriver::Wait.new(timeout: 30)
  wait.until { driver.title.start_with?('Salesforce') }
  puts('Login success.')
rescue StandardError
  puts('Login failed.')
  driver.quit
end

driver.find_element(:class, KINTAI_LINK_CLASS).click
wait = Selenium::WebDriver::Wait.new(timeout: 10)
wait.until { driver.find_element(:id, YEAR_MONTH_LIST_ID).displayed? }

year_month_list = Selenium::WebDriver::Support::Select.new(driver.find_element(:id, YEAR_MONTH_LIST_ID))
year_month_list.select_by(:value, start_date.strftime('%Y%m%d'))
wait = Selenium::WebDriver::Wait.new(timeout: 10)
wait.until { !driver.find_element(:id, 'shim').displayed? }

def input_time(driver, id, val)
  input = driver.find_element(:id, id)
  input.clear
  wait = Selenium::WebDriver::Wait.new(timeout: 10)
  wait.until { input.text.blank? }
  sleep 0.5 if id == 'startTime' # wait until inputable st_input
  input.send_keys(val)
end

(start_date..end_date).each do |date|
  if driver.find_elements(:id, "#{BASE_START_ID}#{date}").empty?
    puts("#{date}:Holiday")
    next
  end
  driver.find_element(:id, "#{BASE_START_ID}#{date}").click
  wait = Selenium::WebDriver::Wait.new(timeout: 10)
  wait.until { driver.find_element(:id, INPUT_DIALOG_ID).displayed? }
  time_submit = driver.find_element(:id, 'dlgInpTimeOk')
  input_time(driver, 'startTime', config['start_time'])
  input_time(driver, 'endTime', config['end_time'])
  time_submit.click
  sleep 0.5 # wait until confirm
  confirm = driver.find_elements(id: 'confirmAlertOk')
  if !confirm.empty? && confirm.first.displayed?
    confirm.first.click
  end

  wait = Selenium::WebDriver::Wait.new(timeout: 10)
  wait.until { !driver.find_element(:id, INPUT_DIALOG_ID).displayed? }
  puts("#{date}:Success")
rescue StandardError => e
  puts("#{date}:Failure")
  puts(e)
end
