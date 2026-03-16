require 'selenium-webdriver'
require 'yaml'
require 'active_support/time'

KINTAI_LINK_ID     = '01r5F000000QZBV_Tab'.freeze
BASE_START_ID      = 'ttvTimeSt'.freeze
INPUT_DIALOG_ID    = 'dijit_DialogUnderlay_0'.freeze
YEAR_MONTH_LIST_ID = 'yearMonthList'.freeze

class AttendanceInputter
  def initialize(config)
    @config = config
    @driver = setup_driver
    @wait   = Selenium::WebDriver::Wait.new(timeout: 10)
  end

  def run(start_date)
    login
    navigate_to_attendance(start_date)
    input_attendance(start_date, start_date.end_of_month)
  ensure
    @driver&.quit
  end

  private

  def setup_driver
    profile_path = @config.fetch('chrome_profile', './chrome_profile')
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--user-data-dir=#{profile_path}")
    Selenium::WebDriver.for(:chrome, options: options)
  end

  def login
    @driver.navigate.to(@config['login_url'])
    @driver.find_element(:id, 'username').send_keys(@config['username'])
    @driver.find_element(:id, 'password').send_keys(@config['password'])
    @driver.find_element(:id, 'Login').click
    Selenium::WebDriver::Wait.new(timeout: 30).until { @driver.title.start_with?('Salesforce') }
    puts 'Login success.'
  rescue StandardError
    raise 'Login failed.'
  end

  def navigate_to_attendance(start_date)
    wait_until { @driver.find_element(:id, KINTAI_LINK_ID).displayed? }
    @driver.find_element(:id, KINTAI_LINK_ID).click
    wait_until { @driver.find_element(:id, YEAR_MONTH_LIST_ID).displayed? }
    year_month_list = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, YEAR_MONTH_LIST_ID))
    year_month_list.select_by(:value, start_date.strftime('%Y%m%d'))
    wait_until { !@driver.find_element(:id, 'shim').displayed? }
  rescue StandardError => e
    raise "Failed to navigate to attendance page: #{e.message}"
  end

  def input_attendance(start_date, end_date)
    (start_date..end_date).each do |date|
      element = @driver.find_elements(:id, "#{BASE_START_ID}#{date}").first
      if element.nil?
        puts "#{date}:Holiday"
        next
      end

      begin
        element.click
        wait_until { @driver.find_element(:id, INPUT_DIALOG_ID).displayed? }
        time_submit = @driver.find_element(:id, 'dlgInpTimeOk')
        input_time('startTime', @config['start_time'])
        input_time('endTime', @config['end_time'])
        time_submit.click
        sleep 0.5 # wait for confirm dialog to appear
        confirm = @driver.find_elements(id: 'confirmAlertOk')
        confirm.first.click if confirm.first&.displayed?
        wait_until { !@driver.find_element(:id, INPUT_DIALOG_ID).displayed? }
        puts "#{date}:Success"
      rescue StandardError => e
        puts "#{date}:Failure"
        puts e
      end
    end
  end

  def input_time(id, val)
    input = @driver.find_element(:id, id)
    input.clear
    wait_until { input.text.blank? }
    sleep 0.5 if id == 'startTime' # wait until start time input becomes inputtable
    input.send_keys(val)
  end

  def wait_until(&block)
    @wait.until(&block)
  end
end

config     = YAML.load_file('config.yml')
today      = Date.today
start_date = ARGV[0].blank? ? (Date.new(today.year, today.month, 1) - 1.month) : Date.parse(ARGV[0]).beginning_of_month

begin
  AttendanceInputter.new(config).run(start_date)
rescue StandardError => e
  puts e.message
  exit 1
end
