require "active_support/all"
require 'date'
require 'json'
require 'openssl'
require 'ecdsa'
require 'byebug'
require 'jwt'
require 'chariwt'
require 'model/test_keys'

$NonceNumber = 1

# monkey patch generate_nonce to return deterministic nonces for testing
class Chariwt::Voucher
  def generate_nonce
    $NonceNumber += 1
    @nonce = sprintf("fakeNonce%05x", $NonceNumber)
  end
end


RSpec.describe Chariwt::VoucherRequest do
  include Testkeys

  describe "properties" do
    it "should have empty properties" do
      vr1 = Chariwt::VoucherRequest.new
      expect(vr1.assertion).to be_nil
      expect(vr1.serialNumber).to be_nil
      expect(vr1.createdOn).to be_nil
      expect(vr1.voucherType).to eq(:unknown)
    end
    it "should set the attributes when properties are set" do
      vr1 = Chariwt::VoucherRequest.new
      vr1.assertion = 'proximity'
      vr1.update_attributes
      expect(vr1.attributes['assertion']).to eq(:proximity)
    end

    it "should set the priorSignedVoucherRequest from a binary string" do
      vr1 = Chariwt::VoucherRequest.new
      vr1.priorSignedVoucherRequest_base64 = "aGVsbG8="
      expect(vr1.priorSignedVoucherRequest).to eq("hello")
    end

  end


  describe "pledge signing" do
    it "should create a JSON format unsigned pledge voucher request" do
      vr1 = Chariwt::VoucherRequest.new
      vr1.assertion    = 'proximity'
      vr1.serialNumber = 'JADA123456789'
      vr1.createdOn    = DateTime.parse('2016-10-07T19:31:42Z')
      vr1.generate_nonce

      vr1.unsigned!

      unsigned_pledge_file="jada123456789.json_u"
      File.open(File.join("tmp", unsigned_pledge_file), "w") do |f|
        f.puts vr1.token_json
      end
      cmd = "diff tmp/#{unsigned_pledge_file} spec/files/#{unsigned_pledge_file}"
      expect(system cmd).to be true
    end

    it "should create a JSON format signed voucher request" do
      vr1 = Chariwt::VoucherRequest.new(:format => :cms)
      vr1.assertion    = 'proximity'
      vr1.serialNumber = 'JADA123456789'
      vr1.createdOn    = DateTime.parse('2016-10-07T19:31:42Z')
      vr1.proximityRegistrarCert = cert_from("jrc_prime256v1")
      vr1.generate_nonce

      vr1.signing_cert_file(File.join("spec","files","jada_prime256v1.crt"))
      vr1.jose_sign_file(File.join("spec","files","jada_prime256v1.key"))

      File.open(File.join("tmp", "pledge_jada123456789.pkix"), "w") do |f|
        f.puts vr1.token
      end
    end

    it "should create a CBOR format unsigned voucher request" do
      vr1 = Chariwt::VoucherRequest.new(:format => :cbor)
      vr1.assertion    = 'proximity'
      vr1.serialNumber = 'JADA123456789'
      vr1.createdOn    = DateTime.parse('2016-10-07T19:31:42Z')
      vr1.nonce        = static_nonce

      #vr1.signing_cert_file(File.join("spec","files","jada_prime256v1.crt"))
      vr1.cbor_unsign

      expect(diagdiff(vr1.token, "pledge_jada123456789")).to be true
    end

    it "should create a CBOR format signed voucher request" do
      vr1 = Chariwt::VoucherRequest.new(:format => :cwt)
      vr1.assertion    = 'proximity'
      vr1.serialNumber = name = 'JADA345768912'
      vr1.createdOn    = DateTime.parse('2016-11-07T19:31:42Z')
      vr1.nonce        = static_nonce
      vr1.proximityRegistrarPublicKey = sig01_pub_key

      vr1.cose_sign(sig01_priv_key, ECDSA::Group::Nistp256, temporary_key)
      expect(Chariwt.cmp_vch_file(vr1.token, name)).to be_truthy
      expect(vr1.signing_object).to_not be_nil
      expect(vr1.signing_object.signature_record).to_not be_nil

      expect(Chariwt.cmp_signing_record(vr1.signing_object.signature_record, name)).to be_truthy
    end
  end

  describe "registrar signing" do
    it "should create a JSON format CMS-signed voucher request, with unsigned pledge request" do
      vr0 = Chariwt::VoucherRequest.new
      vr0.assertion    = 'proximity'
      vr0.serialNumber = 'JADA123456789'
      vr0.createdOn    = DateTime.parse('2016-10-07T19:31:42Z')
      vr0.proximityRegistrarCert = pubkey99
      vr0.generate_nonce
      vr0.unsigned!

      expect(JSON.parse(vr0.token_json)).to_not be_nil

      # now make a voucher request with unsigned pledge request
      vr1 = Chariwt::VoucherRequest.new
      vr1.assertion    = 'proximity'
      vr1.serialNumber = 'JADA123456789'
      vr1.createdOn    = DateTime.parse('2016-10-07T19:31:42Z')
      vr1.cmsSignedPriorVoucherRequest!
      vr1.priorSignedVoucherRequest = vr0.token

      vr1.signing_cert_file(File.join("spec","files","jrc_prime256v1.crt"))
      vr1.pkcs_sign_file(File.join("spec","files","jrc_prime256v1.key"))

      expect(Chariwt.cmp_pkcs_file(vr1.token, "parboiled_jada56789012")).to be true
    end

    it "should JOSE sign a voucher request and save to a file" do
      vr1 = Chariwt::VoucherRequest.new
      vr1.assertion    = 'proximity'
      vr1.serialNumber = 'JADA123456789'
      vr1.createdOn    = DateTime.parse('2016-10-07T19:31:42Z')

      vr1.signing_cert_file(File.join("spec","files","jrc_prime256v1.crt"))
      vr1.jose_sign_file(File.join("spec","files","jrc_prime256v1.key"))

      File.open(File.join("tmp", "jada123456789.jwt"), "w") do |f|
        f.puts vr1.token
      end
      expect(vr1.token).to_not be_nil
    end

    it "should JSON sign a voucher request and save to a file" do
      vr1 = Chariwt::VoucherRequest.new
      vr1.assertion    = 'proximity'
      vr1.serialNumber = 'JADA123456789'
      vr1.createdOn    = DateTime.parse('2016-10-07T19:31:42Z')
      vr1.signing_cert_file(File.join("spec","files","jrc_prime256v1.crt"))
      vr1.pkcs_sign_file(File.join("spec","files","jrc_prime256v1.key"))

      File.open(File.join("tmp", "jada123456789.pkix"), "w") do |f|
        f.puts vr1.token
      end
      expect(vr1.token).to_not be_nil
    end
  end

  describe "loading" do
    it "should load values from a JOSE signed JSON file string" do
      filen = "spec/files/voucher_request1.pkix"
      token = Base64.decode64(IO::read(filen))
      voucher1 = Chariwt::VoucherRequest.from_pkcs7(token, vr1_pubkey)
      expect(voucher1).to_not be_nil

      expect(voucher1.assertion).to    eq(:proximity)
      expect(voucher1.serialNumber).to eq('JADA123456789')
      expect(voucher1.createdOn).to  eq(DateTime.parse('2016-10-07T19:31:42Z'))
      expect(voucher1.voucherType).to eq(:time_based)
    end

    it "should process CMS-signed (parboiled), assertion-less voucher request from Thomas" do
      filen = "spec/files/parboiled_vr-9730-siemens-bt.pkcs"
      token = Base64.decode64(IO::read(filen))
      voucher1 = Chariwt::VoucherRequest.from_pkcs7(token, vr1_pubkey)
      expect(voucher1).to_not be_nil

      expect(voucher1.assertion).to    be_nil
      expect(voucher1.serialNumber).to eq('0123456789')
      expect(voucher1.createdOn).to  eq(DateTime.parse('2018-12-14T05:59:09.256Z'))
      expect(voucher1.voucherType).to eq(:time_based)
    end

    it "should process CMS-signed (parbolied) voucher request via Thomas/BT registrar" do
      token = IO::read("spec/files/siemens-bt-reg29.pkcs")
      voucher1 = Chariwt::VoucherRequest.from_pkcs7(token, vr1_pubkey)
      expect(voucher1).to_not be_nil
    end

    it "should process CMS-signed (pledge) voucher request from Thomas" do
      filen = "spec/files/voucher_request-bt01.pkcs"
      token = Base64.decode64(IO::read(filen))
      voucher1 = Chariwt::VoucherRequest.from_pkcs7(token, vr1_pubkey)
      expect(voucher1).to_not be_nil

      # allow proximity to be blank!
      expect(voucher1.createdOn).to  eq(DateTime.parse('2019-02-05T11:01:26+00:00'))
      expect(voucher1.voucherType).to eq(:time_based)
    end

    it "should load values from a JOSE signed JSON pledge request" do
      filen = "spec/files/pledge_request01.pkcs"
      token = Base64.decode64(IO::read(filen))
      voucher1 = Chariwt::VoucherRequest.from_pkcs7_withoutkey(token)
      expect(voucher1).to_not be_nil

      expect(voucher1.assertion).to    eq(:proximity)
      expect(voucher1.serialNumber).to eq('081196FFFE0181E0')
      expect(voucher1.createdOn).to eq(DateTime.parse('2017-09-01'))
      expect(voucher1.voucherType).to eq(:time_based)
    end

    it "should validate a COSE signed file" do
      pending "THIS TEST DATA IS OLD"
      filen = "spec/files/vr_00-D0-E5-01-00-09.vch"
      certn = "spec/files/010009-idevid.pem"
      pubkey= OpenSSL::X509::Certificate.new(IO::read(certn))

      token = IO::read(filen)
      voucher1 = Chariwt::VoucherRequest.from_cbor_cose(token, pubkey)
      expect(voucher1).to_not be_nil
      pending "update of reference file"
      expect(voucher1.attributes['unknown']).to be nil

      expect(voucher1.assertion).to    eq(:proximity)
      expect(voucher1.serialNumber).to eq('00-D0-E5-01-00-09')
      expect(voucher1.createdOn.utc).to eq(DateTime.parse('2018-05-09T21:04:26Z'))
      expect(voucher1.voucherType).to eq(:request)
    end

    it "should load values from a COSE signed CBOR pledge request, without key" do
      token_io = open("spec/files/vr_00-D0-E5-F2-00-02.vrq")
      voucher1 = Chariwt::VoucherRequest.from_cose_withoutkey_io(token_io)

      expect(voucher1).to_not be_nil
      expect(voucher1.assertion).to    eq(:proximity)
      expect(voucher1.serialNumber).to eq('00-D0-E5-F2-00-02')
      expect(voucher1.createdOn.utc).to eq(DateTime.parse('2019-06-18T02:41:25Z'))
      expect(voucher1.voucherType).to eq(:request)
    end

    it "should not barf on invalid date in JSON string" do
      voucher1 = Chariwt::Voucher.new

      voucher1.createdOn = 'foobar'
      expect(voucher1.createdOn).to be_nil
    end
  end

  describe "json voucher" do
    def sig01_key_base64
      {
        kty:"EC",
        kid:"11",
        crv:"P-256",
        x:"usWxHK2PmfnHKwXPS54m0kTcGJ90UiglWiGahtagnv8",
        y:"IBOL-C3BttVivg-lSreASjpkttcsz-1rb7btKLv8EX4",
        d:"V8kgd2ZBRuh2dgyVINBUqpPDr7BOMGcF22CQMIUHtNM"
      }
    end
    def sig01_rng_stream
      [
         "20DB1328B01EBB78122CE86D5B1A3A097EC44EAC603FD5F60108EDF98EA81393"
      ]
    end
    def sig01_decode_private_key
      bd=ECDSA::Format::IntegerOctetString.decode(Base64.urlsafe_decode64(sig01_key_base64[:d]))
    end

    it "should generate a simple signed voucher, using JOSE with JSON format" do
      ecdsa_key = OpenSSL::PKey::EC.new 'prime256v1'
      ecdsa_key.generate_key
      ecdsa_public = OpenSSL::PKey::EC.new ecdsa_key
      ecdsa_public.private_key = nil

      cv = Chariwt::Voucher.new
      cv.assertion = ''
      cv.serialNumber = 'JADA123456789'
      cv.voucherType = :time_based
      cv.nonce = 'abcd12345'
      cv.createdOn = DateTime.parse('2016-10-07T19:31:42Z')
      cv.expiresOn = DateTime.parse('2017-10-01T00:00:00Z')
      cv.signing_cert = ecdsa_public

      jv = cv.json_voucher
      expect(jv.class).to eq(Hash)
      expect(jv['ietf-voucher:voucher'].class).to eq(Hash)

      token = JWT.encode jv, ecdsa_key, 'ES256'
      File.open("tmp/jada_abcd.jwt","w") do |f|
        f.write token
      end
      (part1,part2,part3) = token.split(/\./)
      part1js = JSON.parse(Base64.urlsafe_decode64(part1))
      part2js = JSON.parse(Base64.urlsafe_decode64(part2))
      part3bin = Base64.urlsafe_decode64(part3)

      expect(part1js['alg']).to eq('ES256')
      expect(part2js['ietf-voucher:voucher']).to_not be_nil
    end
  end

  describe "parsing an EC key" do
    it "should read a private key from a file and sign using ECDSA" do
      base64 = ''
      start = false
      File.open("spec/inputs/key1.pem", "r").each_line { |line|
        if line =~ /-----BEGIN EC PRIVATE KEY-----/
          start=true
          next
        end
        if line =~ /-----END EC PRIVATE KEY-----/
          break
        end
        if start
          base64 += line.chomp
        end
      }
      expect(base64).to_not be_nil
      expect(base64.length).to be > 1
      bin  = Base64.decode64(base64)
      asn1 = OpenSSL::ASN1.decode(bin)

      # described in rfc5915
      #  ECPrivateKey ::= SEQUENCE {
      # version        INTEGER { ecPrivkeyVer1(1) } (ecPrivkeyVer1),
      # privateKey     OCTET STRING,
      # parameters [0] ECParameters {{ NamedCurve }} OPTIONAL,
      # publicKey  [1] BIT STRING OPTIONAL
      #}

      # we care about the algorithm ID and the value
      expect(asn1.tag).to eq(16)  # a sequence
      expect(asn1.value[0].value).to eq(1)
      expect(asn1.value.length).to eq(4)

      # should really process the array of parameters
      expect(asn1.value[2].value[0].value).to eq("prime256v1")

      # grab the private key
      dvalue = asn1.value[1].value
      bd=ECDSA::Format::IntegerOctetString.decode(dvalue)
      expect(bd).to eq(62155652909192118641450531910530083020008790680669046461814889750607491156729)
    end
  end

  describe "certificate SerialNumber" do
    it "should be extracted from subjectAltName othername " do
      vr = Chariwt::VoucherRequest.new
      vr.signing_cert_file("spec/files/pledge_prime256v1.crt")
      expect(vr.eui64_from_cert).to eq("081196FFFE0181E0")
    end
  end

end
