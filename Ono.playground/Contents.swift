import Foundation
import Ono

guard let url = Bundle.main.url(forResource: "nutrition", withExtension: "xml"),
    let data = try? Data(contentsOf: url) else
{
    fatalError("Missing resource: nutrition.xml")
}

let document = try ONOXMLDocument(data: data)
document.rootElement.tag

for element in document.rootElement.children.first?.children ?? [] {
    let nutrient = element.tag
    let amount = element.numberValue!
    let unit = element.attributes["units"]!

    print("- \(amount)\(unit) \(nutrient)")
}

document.enumerateElements(withXPath: "//food/name") { (element, _, _) in
    print(element)
}

document.enumerateElements(withCSS: "food > serving[units]") { (element, _, _) in
    print(element)
}
