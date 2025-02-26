//
//  Globals.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2/26/25.
//

var globalStiResult: NewParseResult?
var globalCcmResult: NewParseResult?

func getAllProducts() -> [Product] {
    var allProducts = [Product]()
    if let stiProducts = globalStiResult?.products {
        allProducts.append(contentsOf: stiProducts)
    }
    if let ccmProducts = globalCcmResult?.products {
        allProducts.append(contentsOf: ccmProducts)
    }
    return allProducts
}
