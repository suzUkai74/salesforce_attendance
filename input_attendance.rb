require 'forwardable'
require 'yaml'
require 'active_support/time'
require_relative 'salesforce_session'

class AttendanceInputter
  extend Forwardable
  # 要素操作は SalesforceSession に委譲する。
  def_delegators :@session, :find, :find_all, :click, :wait_until

  def initialize(config)
    @config      = config
    @attendance  = config.fetch('attendance') { raise 'config.yml に attendance セクションがありません。' }
    selectors    = @attendance.fetch('selectors') { raise 'config.yml に attendance.selectors がありません。' }
    @session     = SalesforceSession.new(config, selectors)
    @driver      = @session.driver
  end

  def run(start_date)
    @session.login
    navigate_to_attendance(start_date)
    input_attendance(start_date, start_date.end_of_month)
  ensure
    @session.wait_for_user
    @session.quit
  end

  private

  def navigate_to_attendance(start_date)
    click(:tab_link)
    wait_until { find(:year_month_list).displayed? }
    year_month_list = Selenium::WebDriver::Support::Select.new(find(:year_month_list))
    year_month_list.select_by(:value, start_date.strftime('%Y%m%d'))
    wait_until { !find(:shim).displayed? }
  rescue StandardError => e
    raise "Failed to navigate to attendance page: #{e.message}"
  end

  def input_attendance(start_date, end_date)
    (start_date..end_date).each do |date|
      element = @driver.find_elements(:id, "#{@session.raw_selector(:time_cell_prefix)}#{date}").first
      if element.nil?
        puts "#{date}:Holiday"
        next
      end

      begin
        element.click
        wait_until { find(:dialog).displayed? }
        time_submit = find(:time_ok)
        input_time(:start_time_input, @attendance['start_time'])
        input_time(:end_time_input, @attendance['end_time'])
        time_submit.click
        sleep 0.5 # wait for confirm dialog to appear
        confirm = find_all(:confirm_button)
        confirm.first.click if confirm.first&.displayed?
        wait_until { !find(:dialog).displayed? }
        puts "#{date}:Success"
      rescue StandardError => e
        puts "#{date}:Failure"
        puts e
      end
    end
  end

  def input_time(key, val)
    input = find(key)
    input.clear
    wait_until { input.text.blank? && input.enabled? }
    input.send_keys(val)
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
