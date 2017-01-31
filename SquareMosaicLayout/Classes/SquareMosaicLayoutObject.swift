import Foundation

private extension SquareMosaicPattern {
    
    func layouts(_ expectedFramesTotalCount: Int) -> [SquareMosaicBlock] {
        let patternBlocks: [SquareMosaicBlock] = blocks
        let patternFramesCount: Int = patternBlocks.map({$0.frames()}).reduce(0, +)
        var layoutTypes = [SquareMosaicBlock]()
        var count: Int = 0
        repeat {
            layoutTypes.append(contentsOf: patternBlocks)
            count += patternFramesCount
        } while (count < expectedFramesTotalCount)
        return layoutTypes
    }
}

class SquareMosaicLayoutObject {
    
    private enum SupplementaryKind {
        case footer, header
        var value: String {
            switch self {
            case .footer:   return UICollectionElementKindSectionFooter
            case .header:   return UICollectionElementKindSectionHeader
            }
        }
    }
    
    fileprivate(set) lazy var cache = [[UICollectionViewLayoutAttributes]]()
    fileprivate(set) lazy var height: CGFloat  = 0.0
    fileprivate(set) lazy var supplementary = [UICollectionViewLayoutAttributes]()
    
    required init(capacity: [Int] = [Int](), dataSource: SquareMosaicLayoutDataSource? = nil, width: CGFloat = 0.0) {
        guard let dataSource = dataSource else { return }
        for section in 0..<capacity.count {
            if let header = dataSource.header(section: section) {
                let indexPath = IndexPath(item: 0, section: section)
                let attributes = supplementary(header, height: &self.height, width: width, kind: .header, indexPath: indexPath)
                supplementary.append(attributes)
            }
            let pattern = dataSource.pattern(section: section)
            var attributes = [UICollectionViewLayoutAttributes]()
            let rows = capacity[section]
            var row: Int = 0
            let layouts = pattern.layouts(rows)
            for layout in layouts {
                guard row < rows else { break }
                let frames = layout.frames(origin: self.height, width: width)
                var height: CGFloat = 0
                for x in 0..<layout.frames() {
                    guard row < rows else { break }
                    let indexPath = IndexPath(row: row, section: section)
                    let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                    attribute.frame = frames[x]
                    let dy = attribute.frame.origin.y + attribute.frame.height - self.height
                    height = dy > height ? dy : height
                    attributes.append(attribute)
                    row += 1
                }
                self.height += height
            }
            cache.append(attributes)
            if let footer = dataSource.footer(section: section) {
                let indexPath = IndexPath(item: 0, section: section)
                let attributes = supplementary(footer, height: &self.height, width: width, kind: .footer, indexPath: indexPath)
                supplementary.append(attributes)
            }
        }
    }
    
    private func supplementary(_ supplementary: SquareMosaicSupplementary, height: inout CGFloat, width: CGFloat, kind: SquareMosaicLayoutObject.SupplementaryKind, indexPath: IndexPath) -> UICollectionViewLayoutAttributes {
        let frame = supplementary.frame(origin: height, width: width)
        let attribute = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: kind.value, with: indexPath)
        attribute.frame = frame
        height += frame.height
        return attribute
    }
}

extension SquareMosaicLayoutObject {
    
    func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section < cache.count else { return  nil }
        guard indexPath.row < cache[indexPath.section].count else { return nil }
        return cache[indexPath.section][indexPath.row]
    }
    
    func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let cache = self.cache.flatMap({$0}).filter({$0.frame.intersects(rect)})
        let supplementary = self.supplementary.filter({$0.frame.intersects(rect)})
        return cache + supplementary
    }
    
    func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return supplementary
            .filter({ $0.indexPath == indexPath })
            .filter({ $0.representedElementKind == elementKind })
            .first
    }
}