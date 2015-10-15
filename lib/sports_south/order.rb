require 'net/http'
require 'nokogiri'

module SportsSouth
  class Order < Base

    API_URL = 'http://webservices.theshootingwarehouse.com/smart/orders.asmx'

    SHIP_VIA = {
      ground:    '',
      next_day:  'N',
      two_day:   '2',
      three_day: '3',
      saturday:  'S',
    }

    def initialize(options = {})
      requires!(options, :username, :password, :source, :customer_number)
      @options = options
    end

    def add_header(header = {})
      requires!(header, :purchase_order, :sales_message, :shipping)
      header[:customer_order_number] = header[:purchase_order] unless header.has_key?(:customer_order_number)
      header[:adult_signature] = false unless header.has_key?(:adult_signature)
      header[:signature] = false unless header.has_key?(:signature)
      header[:insurance] = false unless header.has_key?(:insurance)

      requires!(header[:shipping], :name, :address_one, :city, :state, :zip, :phone)
      header[:shipping][:attn] = header[:shipping][:name] unless header.has_key?(:attn)
      header[:shipping][:via] = SHIP_VIA[:ground] unless header.has_key?(:ship_via)
      header[:shipping][:address_two] = '' unless header[:shipping].has_key?(:address_two)

      http, request = get_http_and_request('/AddHeader')

      request.set_form_data(form_params.merge({
        PO: header[:purchase_order],
        CustomerOrderNumber: header[:customer_order_number],
        SalesMessage: header[:sales_message],

        ShipVia: header[:shipping][:via],
        ShipToName: header[:shipping][:name],
        ShipToAttn: header[:shipping][:attn],
        ShipToAddr1: header[:shipping][:address_one],
        ShipToAddr2: header[:shipping][:address_two],
        ShipToCity: header[:shipping][:city],
        ShipToState: header[:shipping][:state],
        ShipToZip: header[:shipping][:zip],
        ShipToPhone: header[:shipping][:phone],

        AdultSignature: header[:adult_signature],
        Signature: header[:signature],
        Insurance: header[:insurance],
      }))

      response = http.request(request)
      xml_doc  = Nokogiri::XML(response.body)

      @order_number = xml_doc.content
    end

    def add_detail(detail = {})
      raise StandardError.new("No @order_number present.") if @order_number.nil?

      requires!(detail, :ss_item_number, :price)
      detail[:quantity] = 1 unless detail.has_key?(:quantity)
      detail[:item_number] = '' unless detail.has_key?(:item_number)
      detail[:item_description] = '' unless detail.has_key?(:item_description)

      http, request = get_http_and_request('/AddDetail')

      request.set_form_data(form_params.merge({
        OrderNumber: @order_number,
        SSItemNumber: detail[:ss_item_number],
        Quantity: detail[:quantity],
        OrderPrice: detail[:price],
        CustomerItemNumber: detail[:item_number],
        CustomerItemDescription: detail[:item_description],
      }))

      response = http.request(request)
      xml_doc = Nokogiri::XML(response.body)

      xml_doc.content == 'true'
    end

    def submit!
      raise 'Not yet implemented.'
    end

    private

    # Returns a hash of common form params.
    def form_params
      {
        UserName: @options[:username],
        Password: @options[:password],
        CustomerNumber: @options[:customer_number],
        Source: @options[:source],
      }
    end

    def get_http_and_request(endpoint)
      uri = URI([API_URL, endpoint].join)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)

      return http, request
    end

  end
end
