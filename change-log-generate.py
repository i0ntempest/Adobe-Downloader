def generate_xml(changelog_cn, changelog_en, ps_cn, ps_en):
    xml_template = """
    <description>
        <![CDATA[
            <style>ul{{margin-top: 0;margin-bottom: 7;padding-left: 18;}}</style>
            <h4>Adobe Downloader 更新日志: </h4>
            <ul>
                {changelog_cn}
            </ul>
            <h4>PS: {ps_cn}</h4>
            <hr>
            <h4>Adobe Downloader Changes: </h4>
            <ul>
                {changelog_en}
            </ul>
            <h4>PS: {ps_en}</h4>
        ]]>
    </description>
    """

    changelog_cn_list = "\n".join([f"<li>{item}</li>" for item in changelog_cn])
    changelog_en_list = "\n".join([f"<li>{item}</li>" for item in changelog_en])

    return xml_template.format(
        changelog_cn=changelog_cn_list,
        changelog_en=changelog_en_list,
        ps_cn="<br>".join(ps_cn),
        ps_en="<br>".join(ps_en)
    )


def parse_input(text):
    sections = text.split("====================")

    if len(sections) < 2:
        raise ValueError("输入格式错误，必须包含 '====================' 作为分隔符")

    cn_lines = [line.strip() for line in sections[0].split("\n") if line.strip()]
    en_lines = [line.strip() for line in sections[1].split("\n") if line.strip()]

    changelog_cn, ps_cn, changelog_en, ps_en = [], [], [], []

    for line in cn_lines:
        if line.startswith("PS:"):
            ps_cn.append(line.replace("PS: ", ""))
        else:
            changelog_cn.append(line)

    for line in en_lines:
        if line.startswith("PS:"):
            ps_en.append(line.replace("PS: ", ""))
        else:
            changelog_en.append(line)

    return changelog_cn, changelog_en, ps_cn, ps_en


def main():
    txt = """1. 修复部分情况下，Helper 无法重新连接的情况
2. 修复部分情况下，重新安装程序以及重新安装 Helper 的无法连接的情况
3. 调整 X1a0He CC 部分，1.5.0 版本可以选择 "下载并处理" 和 "仅下载"
4. 调整了部分 Setup 组件的内容翻译
5. 程序设置页中添加 「清理工具」 和 「常见问题」功能
6. 程序设置页中，添加当前版本显示

PS: 当前版本添加的 「清理工具」功能为实验性功能，如有清理不全，请及时反馈
PS: ⚠️ 1.5.0 版本将会是最后一个开源版本，请知晓

====================

1. Fixed the issue of Helper not being able to reconnect in some cases
2. Fixed the issue of not being able to reconnect after reinstalling the program and reinstalling Helper
3. Adjusted the content translation of X1a0He CC, version 1.5.0 can choose "Download and Process" and "Only Download"
4. Adjusted the translation of some Setup component content
5. Added "Cleanup Tool" and "Common Issues" functions in the program settings page
6. Added the current version display in the program settings page

PS: The "Cleanup Tool" function in the current version is an experimental feature. If some files are not cleaned up, please feedback in time
PS: ⚠️ 1.5.0 version will be the last open source version, please be aware"""

    changelog_cn, changelog_en, ps_cn, ps_en = parse_input(txt)
    xml_output = generate_xml(changelog_cn, changelog_en, ps_cn, ps_en)
    print(xml_output)


if __name__ == "__main__":
    main()
