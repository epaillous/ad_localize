module AdLocalize::Platform
  class IosFormatter < PlatformFormatter
    def platform
      :ios
    end

    def export(locale, data, export_extension = nil, substitution_format = nil)
      create_locale_dir(locale)
      all_symbols = [
        AdLocalize::Constant::PLURAL_KEY_SYMBOL,
        AdLocalize::Constant::ADAPTIVE_KEY_SYMBOL,
        AdLocalize::Constant::SINGULAR_KEY_SYMBOL,
        AdLocalize::Constant::INFO_PLIST_KEY_SYMBOL
      ]
      all_symbols.each do |numeral_key|
        numeral_data = data.select {|key, wording| wording.dig(locale.to_sym)&.key? numeral_key}
        if numeral_data.empty?
          AdLocalize::LOGGER.log(:info, :black, "[#{locale.upcase}] no #{numeral_key.to_s} keys were found to generate the file")
        else
          send("write_#{numeral_key}", locale, numeral_data)
        end
      end
    end

    protected

    def write_singular(locale, singulars)
      write_localizable(
        locale: locale,
        singulars: singulars,
        wording_type: AdLocalize::Constant::SINGULAR_KEY_SYMBOL,
        filename: AdLocalize::Constant::IOS_SINGULAR_EXPORT_FILENAME
      )
    end

    def write_info_plist(locale, singulars)
      write_localizable(
        locale: locale,
        singulars: singulars,
        wording_type: AdLocalize::Constant::INFO_PLIST_KEY_SYMBOL,
        filename: AdLocalize::Constant::IOS_INFO_PLIST_EXPORT_FILENAME
      )
    end

    def write_plural(locale, plurals)
      locale = locale.to_sym

      append_to_localizable_plist(locale) do |xml|
        plurals.each do |wording_key, translations|
          xml.key wording_key
          xml.dict {
            xml.key "NSStringLocalizedFormatKey"
            xml.string "%\#@key@"
            xml.key "key"
            xml.dict {
              xml.key "NSStringFormatSpecTypeKey"
              xml.string "NSStringPluralRuleType"
              xml.key "NSStringFormatValueTypeKey"
              xml.string "d"
              translations[locale][AdLocalize::Constant::PLURAL_KEY_SYMBOL].each do |wording_type, wording_value|
                xml.key wording_type
                xml.string wording_value
              end
            }
          }
        end
      end
      AdLocalize::LOGGER.log(:debug, :black, "iOS plural [#{locale}] ---> DONE!")
    end

    def write_adaptive(locale, adaptives)
      locale = locale.to_sym

      append_to_localizable_plist(locale) do |xml|
        adaptives.each do |wording_key, translations|
          xml.key wording_key
          xml.dict {
            xml.key "NSStringVariableWidthRuleType"
            xml.dict {
              translations[locale][AdLocalize::Constant::ADAPTIVE_KEY_SYMBOL].each do |wording_type, wording_value|
                xml.key wording_type
                xml.string wording_value
              end
            }
          }
        end
      end
      AdLocalize::LOGGER.log(:debug, :black, "iOS adaptive [#{locale}] ---> DONE!")
    end

    private

    def write_localizable(locale:, singulars:, wording_type:, filename:)
      locale = locale.to_sym

      singulars.each do |key, locales_wording|
        value = locales_wording.dig(locale, wording_type)
        comment = locales_wording.dig(locale, AdLocalize::Constant::COMMENT_KEY_SYMBOL)
        export_dir(locale).join(filename).open("a") do |file|
          line = ""
          if wording_type == AdLocalize::Constant::INFO_PLIST_KEY_SYMBOL
            line = %(#{key} = "#{value}";)
          else
            line = %("#{key}" = "#{value}";)
          end
          line << " // #{comment}" unless comment.nil?
          line << "\n"
          file.puts line
        end
      end
      AdLocalize::LOGGER.log(:debug, :black, "iOS #{wording_type} [#{locale}] ---> DONE!")
    end

    def append_to_localizable_plist(locale)
      filename = export_dir(locale).join(AdLocalize::Constant::IOS_PLURAL_EXPORT_FILENAME)
      xml_doc = nil
      if File.exist?(filename)
        xml_content = Nokogiri::XML(open(filename)) do |config|
          config.default_xml.noblanks # minimify xml
        end
        xml_doc = Nokogiri::XML::Builder.with(xml_content.css('plist>dict').first) do |xml|
          yield(xml)
        end
      else
        xml_doc = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.plist {
            xml.dict {
              yield(xml)
            }
          }
        end
      end
      filename.open("w") do |file|
        file.puts xml_doc.to_xml(indent: 4)
      end
    end
  end
end