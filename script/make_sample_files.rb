#!/usr/bin/env ruby
# Tạo file PPTX/DOCX mẫu để test convert. Không cần thêm gem — chỉ cần rubyzip có sẵn.
require "zip"
require "fileutils"
require "tmpdir"

OUTPUT_DIR = ARGV[0] || "."

def make_pptx(path, slide_titles)
  Zip::File.open(path, create: true) do |zip|
    zip.get_output_stream("[Content_Types].xml") do |f|
      f.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          #{(1..slide_titles.size).map { |i| %(<Override PartName="/ppt/slides/slide#{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>) }.join("\n  ")}
        </Types>
      XML
    end

    zip.get_output_stream("_rels/.rels") do |f|
      f.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
      XML
    end

    zip.get_output_stream("ppt/presentation.xml") do |f|
      slide_ids = (1..slide_titles.size).map { |i| %(<p:sldId id="#{255 + i}" r:id="rId#{i}"/>) }.join
      f.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:sldIdLst>#{slide_ids}</p:sldIdLst>
          <p:sldSz cx="9144000" cy="6858000"/>
        </p:presentation>
      XML
    end

    zip.get_output_stream("ppt/_rels/presentation.xml.rels") do |f|
      rels = (1..slide_titles.size).map { |i| %(<Relationship Id="rId#{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide#{i}.xml"/>) }.join
      f.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          #{rels}
        </Relationships>
      XML
    end

    slide_titles.each_with_index do |title, i|
      n = i + 1
      zip.get_output_stream("ppt/slides/slide#{n}.xml") do |f|
        f.write(<<~XML)
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
            <p:cSld>
              <p:sp>
                <p:nvSpPr><p:cNvPr id="1" name="Title"/><p:cNvSpPr/></p:nvSpPr>
                <p:spPr><a:xfrm xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:off x="0" y="0"/><a:ext cx="9144000" cy="6858000"/></a:xfrm></p:spPr>
                <p:txBody>
                  <a:p xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:r><a:rPr lang="vi-VN" sz="4400"/><a:t>#{title}</a:t></a:r>
                  </a:p>
                </p:txBody>
              </p:sp>
            </p:cSld>
          </p:sld>
        XML
      end
    end
  end
end

def make_docx(path, paragraphs)
  Zip::File.open(path, create: true) do |zip|
    zip.get_output_stream("[Content_Types].xml") do |f|
      f.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
      XML
    end
    zip.get_output_stream("_rels/.rels") do |f|
      f.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
      XML
    end
    body = paragraphs.map { |p| %(<w:p><w:r><w:t xml:space="preserve">#{p}</w:t></w:r></w:p>) }.join
    zip.get_output_stream("word/document.xml") do |f|
      f.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>#{body}</w:body>
        </w:document>
      XML
    end
  end
end

pptx_path = File.join(OUTPUT_DIR, "sample_presentation.pptx")
docx_path = File.join(OUTPUT_DIR, "sample_document.docx")

make_pptx(pptx_path, [
  "Seminar Link — Trang 1",
  "Trang 2 — Upload & Trình chiếu",
  "Trang 3 — PDF.js + LibreOffice"
])
puts "Wrote #{pptx_path}"

make_docx(docx_path, [
  "Seminar Link — Test Document",
  "Dòng thứ hai của tài liệu.",
  "Convert bằng LibreOffice sang PDF để trình chiếu."
])
puts "Wrote #{docx_path}"