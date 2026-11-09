import os
import glob
from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

# ==========================================
# 1. إعداد بيانات الطالب (تأكد من مراجعة رقمك الجامعي)
# ==========================================
STUDENT_NAME = "فرحات سعفان محمد محمد سعفان"
STUDENT_ID = "اكتب_رقمك_الجامعي_هنا"  # <-- عدّل الرقم الجامعي هنا قبل التشغيل
OUTPUT_DOCX = "Farahat_Saafan_EKB_Assignment.docx"
OUTPUT_PDF = "Farahat_Saafan_EKB_Assignment.pdf"

# ==========================================
# 2. دوال ضبط اتجاه اللغة العربية (RTL) والجداول
# ==========================================
def set_rtl_paragraph(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    pPr = paragraph._p.get_or_add_pPr()
    bidi = OxmlElement('w:bidi')
    pPr.append(bidi)

def set_rtl_table(table):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    tblPr = table._tbl.tblPr
    bidiVisual = OxmlElement('w:bidiVisual')
    tblPr.append(bidiVisual)

def format_run(run, font_size=12, bold=False, color=None):
    run.font.name = 'Arial'
    run.font.size = Pt(font_size)
    run.bold = bold
    if color:
        run.font.color.rgb = RGBColor(*color)
    rPr = run._r.get_or_add_rPr()
    rtl = OxmlElement('w:rtl')
    rPr.append(rtl)

def add_rtl_heading(doc, text, level=1):
    p = doc.add_paragraph()
    set_rtl_paragraph(p)
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(6)
    size = 16 if level == 1 else (14 if level == 2 else 12)
    color = (0, 51, 102) if level == 1 else ((0, 102, 153) if level == 2 else (30, 30, 30))
    run = p.add_run(text)
    format_run(run, font_size=size, bold=True, color=color)
    return p

def add_rtl_paragraph(doc, text, bold_prefix="", font_size=12):
    p = doc.add_paragraph()
    set_rtl_paragraph(p)
    p.paragraph_format.line_spacing = 1.3
    p.paragraph_format.space_after = Pt(6)
    if bold_prefix:
        r_bold = p.add_run(bold_prefix)
        format_run(r_bold, font_size=font_size, bold=True, color=(20, 20, 20))
    r_text = p.add_run(text)
    format_run(r_text, font_size=font_size, bold=False)
    return p

# ==========================================
# 3. دالة البحث التلقائي عن لقطات الشاشة وإدراجها
# ==========================================
def find_and_insert_image(doc, timestamp_key, caption_text=""):
    home = Path.home()
    search_dirs = [
        Path.cwd(),
        home / "Pictures" / "Screenshots",
        home / "OneDrive" / "Pictures" / "Screenshots",
        home / "Desktop",
        home / "Downloads"
    ]
    
    found_path = None
    for d in search_dirs:
        if d.exists():
            matches = list(d.glob(f"*{timestamp_key}*.*"))
            if matches:
                found_path = str(matches[0])
                break

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    if found_path and os.path.exists(found_path):
        run = p.add_run()
        run.add_picture(found_path, width=Inches(5.8))
        print(f"[✔] تم إدراج الصورة بنجاح: {os.path.basename(found_path)}")
    else:
        run = p.add_run(f"[تنبيه: لم يتم العثور على الصورة التي تحتوي على الرقم {timestamp_key} تلقائياً - ضعها هنا يدوياً]")
        format_run(run, font_size=11, bold=True, color=(200, 0, 0))
        print(f"[!] لم يتم العثور تلقائياً على الصورة: {timestamp_key}")

    if caption_text:
        cap = doc.add_paragraph()
        cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r_cap = cap.add_run(caption_text)
        format_run(r_cap, font_size=10, bold=True, color=(100, 100, 100))

def create_styled_table(doc, headers, rows):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = 'Table Grid'
    set_rtl_table(table)
    
    hdr_cells = table.rows[0].cells
    for i, header_text in enumerate(headers):
        hdr_cells[i].text = ""
        p = hdr_cells[i].paragraphs[0]
        set_rtl_paragraph(p)
        run = p.add_run(header_text)
        format_run(run, font_size=11, bold=True, color=(0, 51, 102))

    for row_data in rows:
        row_cells = table.add_row().cells
        for i, val in enumerate(row_data):
            row_cells[i].text = ""
            p = row_cells[i].paragraphs[0]
            set_rtl_paragraph(p)
            run = p.add_run(val)
            format_run(run, font_size=10.5, bold=(i == 0))
    doc.add_paragraph()

# ==========================================
# 4. بناء محتوى المستند بالكامل
# ==========================================
def build_assignment():
    doc = Document()

    # --- ترويسة الغلاف ---
    add_rtl_heading(doc, "جامعة المنصورة الجديدة (NMU) - كلية علوم وهندسة الحاسب", level=1)
    add_rtl_heading(doc, "تكليف عملي: استخدام بنك المعرفة المصري (EKB) في البحث العلمي", level=2)
    add_rtl_paragraph(doc, "د. تسنيم", bold_prefix="مقدم إلى: ")
    add_rtl_paragraph(doc, STUDENT_NAME, bold_prefix="اسم الطالب: ")
    add_rtl_paragraph(doc, STUDENT_ID, bold_prefix="الرقم الجامعي (ID): ")
    add_rtl_paragraph(
        doc,
        "الذكاء الاصطناعي وتطبيقاته في معالجة اللغات الطبيعية والتعلم العميق (Artificial Intelligence, Natural Language Processing & Deep Learning).",
        bold_prefix="موضوع البحث المختار: "
    )
    doc.add_paragraph("─" * 55)

    # --- أولاً: اختيار موضوع البحث ---
    add_rtl_heading(doc, "1. اختيار موضوع البحث", level=1)
    add_rtl_paragraph(
        doc,
        "تم اختيار موضوع الذكاء الاصطناعي (Artificial Intelligence) وتطبيقاته الفرعية في معالجة اللغات الطبيعية (Natural Language Processing) والتعلم العميق (Deep Learning) لارتباطه المباشر بتخصصي الأكاديمي في علوم الذكاء الاصطناعي."
    )

    # --- ثانياً: تطبيق استراتيجيات البحث ---
    add_rtl_heading(doc, "2. تطبيق استراتيجيات البحث على بنك المعرفة المصري", level=1)

    # أ. البحث البسيط
    add_rtl_heading(doc, "أ. إجراء البحث البسيط (Basic Search):", level=2)
    find_and_insert_image(doc, "175856", "شكل (1): إجراء البحث البسيط باستخدام الكلمة المفتاحية Artificial Intelligence")
    add_rtl_paragraph(
        doc,
        "تم إجراء بحث بسيط عبر محرك البحث الموحد لبنك المعرفة المصري باستخدام الكلمة المفتاحية المباشرة \"Artificial Intelligence\" داخل حقل الكلمات المفتاحية (Keyword) مع تحديد خيار (All these words). أسفرت العملية عن استرجاع نحو 8,834,822 نتيجة موزعة عبر 55 مصدراً وقاعدة بيانات عالمية (مثل Scopus وSpringerLink وScienceDirect)، مما يوضح اتساع النطاق العام للبحث البسيط وحاجته إلى التخصيص.",
        bold_prefix="تفسير الخطوة والنتائج: "
    )

    # ب. البحث المتقدم
    add_rtl_heading(doc, "ب. إجراء البحث المتقدم (Advanced Search):", level=2)
    find_and_insert_image(doc, "182021", "شكل (2): إجراء البحث المتقدم باستخدام المعاملات المنطقية AND و OR")
    add_rtl_paragraph(
        doc,
        "تم الانتقال إلى البحث المتقدم لإدخال ثلاث كلمات مفتاحية والربط بينها بالمعاملات البولينية؛ حيث استُخدم المعامل (And) للربط بين \"Artificial Intelligence\" ومصطلح \"Natural Language Processing\" لاشتراط وجود المفهومين معاً، واستُخدم المعامل (Or) لإضافة مصطلح \"Deep Learning\" لتوسيع الاسترجاع ليشمل الأبحاث المتعلقة بالتعلم العميق، مما أدى إلى تنقية وتخصيص النتائج لتصل إلى 7,847,442 نتيجة.",
        bold_prefix="تفسير الخطوة وكيفية استخدام المعاملات: "
    )

    # ج. فلاتر البحث
    add_rtl_heading(doc, "ج. استخدام فلاتر البحث لتضييق نطاق النتائج:", level=2)
    find_and_insert_image(doc, "194443", "شكل (3-أ): تطبيق فلاتر سنة النشر (Dates) ونوع المحتوى (Content Types: Book)")
    find_and_insert_image(doc, "195946", "شكل (3-ب): تخصيص المؤشر الزمني لتواريخ النشر من قائمة Refine your Results")
    add_rtl_paragraph(
        doc,
        "تم استخدام الفلاتر الجانبية المتاحة لتضييق النتائج عبر فلتر سنة النشر (Dates) لحصر المؤلفات المنشورة حتى عام 2026، بالإضافة إلى فلتر نوع المحتوى (Content Types) لتحديد الكتب الإلكترونية (Book: 15)، مما ساعد على تصفية النتائج والوصول المباشر إلى المراجع العلمية المطابقة لمعايير البحث.",
        bold_prefix="تفسير الخطوة والنتائج: "
    )

    # د. فلتر المعارف
    add_rtl_heading(doc, "د. استخدام فلتر المعارف (Knowledge Filter):", level=2)
    find_and_insert_image(doc, "195337", "شكل (4-أ): واجهة فلتر المعارف وتقسيماته حسب المؤلفين والمصادر والمساهمين")
    find_and_insert_image(doc, "195558", "شكل (4-ب): تطبيق استكشاف المعارف (Discover: Artificial Intelligence)")
    add_rtl_paragraph(
        doc,
        "تم تفعيل تبويب فلتر المعارف (Disciplines / Discover) لاستكشاف مصادر المعلومات المناسبة لموضوع الذكاء الاصطناعي (Discover: Artificial Intelligence). أتاح الفلتر تقسيم النتائج المسترجعة (83,049 نتيجة) إلى تصنيفات معرفية منظمة تشمل: أبرز المؤلفين (Authors: 50)، ومصادر النشر (Sources: 19 مثل DOAJ وIOP وSpringerNature)، واللغات (Languages: 36)، والناشرين (Publishers: 50)، إلى جانب المصطلحات المعرفية المحكومة (Controlled Terms).",
        bold_prefix="تفسير الخطوة والنتائج: "
    )

    # --- ثالثاً: البحث داخل قواعد البيانات ---
    add_rtl_heading(doc, "3. البحث داخل قواعد البيانات المتخصصة", level=1)
    find_and_insert_image(doc, "191537", "شكل (5): إجراء البحث داخل قاعدة بيانات Scopus العالمية")
    add_rtl_paragraph(doc, "قاعدة بيانات Scopus (Elsevier).", bold_prefix="• اسم قاعدة البيانات المختارة: ")
    add_rtl_paragraph(
        doc,
        "لأنها تُعد أكبر وأدق قاعدة بيانات عالمية للمستخلصات والاستشهادات المرجعية للأبحاث العلمية المحكمة (Peer-Reviewed Literature)، وتضم أقوى الدوريات والمؤتمرات في مجالات الذكاء الاصطناعي وعلوم الحاسب، مع توفير أدوات تحليل وفرز متقدمة حسب الحداثة وعدد الاستشهادات.",
        bold_prefix="• سبب اختيارها: "
    )
    add_rtl_paragraph(
        doc,
        "تتيح المقالات العلمية المنشورة في الدوريات المحكمة (Journal Articles)، ومقالات المراجعة المنهجية (Reviews)، وأوراق عمل المؤتمرات الدولية (Conference Papers)، والكتب العلمية، والمسودات البحثية الأولية (Preprints).",
        bold_prefix="• نوع المعلومات التي تتيحها للباحث: "
    )

    # --- رابعاً: توثيق المصادر ---
    add_rtl_heading(doc, "4. تحديد مصادر المعلومات العلمية وتوثيقها", level=1)
    sources_headers = ["البيان الببليوجرافي", "المصدر العلمي الأول (مقال علمي - Scopus)", "المصدر العلمي الثاني (كتاب إلكتروني - EKB)"]
    sources_rows = [
        ["عنوان المصدر", "A bibliometric and systematic analysis of artificial intelligence and the transition towards smart geotourism", "Machine learning for tomographic imaging"],
        ["اسم المؤلف / المؤلفين", "Aguirre-Suarez T., Perez-Chiquito M., Cochea-Tomala H., Escandon-Panchana P.", "Ge Wang, Yi Zhang, Xiaojing Ye, Xuanqin Mou"],
        ["سنة النشر", "2027", "2020"],
        ["اسم المجلة أو الناشر", "Global Journal of Environmental Science and Management, 13(1)", "Institute of Physics (Great Britain) | IOP Books"],
        ["رابط المصدر أو رقم DOI", "متاح عبر قاعدة بيانات Scopus من خلال رابط الناشر (View at Publisher)", "متاح عبر بنك المعرفة المصري ومكتبة IOP Books (EKB LinkResolver)"],
        ["نوع المصدر", "مقال علمي محكّم / مراجعة منهجية (Review Article)", "كتاب إلكتروني (eBook)"]
    ]
    create_styled_table(doc, sources_headers, sources_rows)

    # --- خامساً: الأسئلة النظرية ---
    add_rtl_heading(doc, "5. الإجابة عن الأسئلة النظرية", level=1)

    add_rtl_heading(doc, "س1: إذا أردت إجراء بحث عن \"استخدام الذكاء الاصطناعي في اكتشاف الثغرات الأمنية\"، كيف ستبدأ البحث على بنك المعرفة المصري؟", level=2)
    add_rtl_paragraph(doc, "1. تحليل الموضوع واستخراج الكلمات المفتاحية بالإنجليزية: تقسيم الموضوع إلى مفهومين؛ المفهوم الأول هو الذكاء الاصطناعي (\"Artificial Intelligence\" أو \"Machine Learning\" أو \"Deep Learning\")، والمفهوم الثاني هو اكتشاف الثغرات الأمنية (\"Vulnerability Detection\" أو \"Security Vulnerabilities\" أو \"Cybersecurity\").")
    add_rtl_paragraph(doc, "2. استخدام البحث المتقدم (Advanced Search): كتابة صيغة بحثية مركّبة تربط المرادفات بـ OR وتربط المفهومين معاً بـ AND كالتالي:\n(\"Artificial Intelligence\" OR \"Machine Learning\") AND (\"Vulnerability Detection\" OR \"Security Vulnerabilities\")")
    add_rtl_paragraph(doc, "3. تطبيق فلاتر التضييق: تحديد سنة النشر في السنوات الخمس الأخيرة لمواكبة حداثة تقنيات الأمن السيبراني، وتحديد نوع المحتوى في المقالات المحكمة وأوراق المؤتمرات.")
    add_rtl_paragraph(doc, "4. البحث داخل قواعد البيانات المتخصصة: الدخول إلى قواعد بيانات علوم الحاسب مثل IEEE Xplore أو Scopus أو ScienceDirect لتحميل النصوص الكاملة (Full-Text PDF) وتوثيقها.")

    add_rtl_heading(doc, "س2: ما الفرق بين البحث البسيط (Basic Search) والبحث المتقدم (Advanced Search)؟", level=2)
    comp_headers = ["وجه المقارنة", "البحث البسيط (Basic Search)", "البحث المتقدم (Advanced Search)"]
    comp_rows = [
        ["آلية البحث", "يعتمد على خانة بحث واحدة تُكتب فيها كلمة مفتاحية عامة أو عبارة قصيرة.", "يوفّر عدة خانات بحثية مترابطة بمعاملات منطقية (AND, OR, NOT)."],
        ["حجم ودقة النتائج", "يسترجع ملايين النتائج العامة، ويكون كثير منها غير مرتبط بدقة بهدف الباحث.", "يسترجع عدداً أقل من النتائج، لكنها عالية الدقة ومرتبطة مباشرة بصلب الموضوع."],
        ["تخصيص الحقول", "يبحث في جميع الحقول تلقائياً دون تمييز.", "يسمح بتحديد حقل البحث بدقة (العنوان Title، المستخلص Abstract، المؤلف Author، الكلمات المفتاحية Keywords)."],
        ["الاستخدام الأمثل", "مناسب للاستكشاف المبدئي السريع لموضوع جديد، أو البحث عن عنوان معروف بالاسم.", "مناسب للبحث الأكاديمي الدقيق في الموضوعات المركّبة متعددة المتغيرات."]
    ]
    create_styled_table(doc, comp_headers, comp_rows)

    add_rtl_heading(doc, "س3: متى تستخدم معامل البحث (AND) بدلاً من (OR)؟", level=2)
    add_rtl_paragraph(
        doc,
        "عند الرغبة في تضييق وتخصيص نطاق البحث (الربط بين مفهومين مختلفين)؛ حيث يشترط محرك البحث ظهور جميع الكلمات المفتاحية معاً داخل نفس المصدر العلمي، مثل كتابة \"Artificial Intelligence\" AND \"Vulnerability Detection\" لاسترجاع الأبحاث التي جمعت بين المفهومين معاً فقط.",
        bold_prefix="• نستخدم المعامل (AND): "
    )
    add_rtl_paragraph(
        doc,
        "عند الرغبة في توسيع نطاق البحث (الربط بين المرادفات والمصطلحات البديلة لنفس المفهوم)؛ حيث يكتفي محرك البحث بظهور أي كلمة من الكلمات المكتوبة على الأقل داخل المصدر، مثل كتابة \"Artificial Intelligence\" OR \"Machine Learning\" لضمان عدم ضياع أبحاث استخدمت مصطلحاً مرادفاً.",
        bold_prefix="• نستخدم المعامل (OR): "
    )

    # حفظ ملف الوورد
    doc.save(OUTPUT_DOCX)
    print(f"\n[✔] تم إنشاء ملف الوورد بنجاح: {os.path.abspath(OUTPUT_DOCX)}")

    # تحويل تلقائي إلى PDF
    try:
        from docx2pdf import convert
        print("[⏳] جاري تحويل الملف إلى PDF تلقائياً عبر Microsoft Word...")
        convert(OUTPUT_DOCX, OUTPUT_PDF)
        print(f"[✔] تم إنشاء ملف الـ PDF بنجاح: {os.path.abspath(OUTPUT_PDF)}")
    except Exception as e:
        print(f"[!] ملاحظة: تعذر التحويل التلقائي لـ PDF ({e}). يمكنك فتح ملف الوورد الناتج وحفظه كـ PDF مباشرة (F12 -> PDF).")

if __name__ == "__main__":
    build_assignment()