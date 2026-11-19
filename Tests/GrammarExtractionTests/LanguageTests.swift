import Testing
@testable import GrammarExtraction

struct LanguageTests {

    func sym(_ s: String) -> GrammarExpression { .symbol(s) }

    @Test func equivalentExpressionsHaveNoDifference() {
        // a { , a }   ==   { a , } a
        let x = GrammarExpression.sequence([sym("a"), .repetition(.sequence([sym(","), sym("a")]))])
        let y = GrammarExpression.sequence([.repetition(.sequence([sym("a"), sym(",")])), sym("a")])
        #expect(Language.difference(x.language, y.language) == nil)
    }

    @Test func differenceReportsShortestWitness() {
        let x = GrammarExpression.sequence([sym("a"), .choice([.empty, sym("b")])])
        let y = sym("a")
        #expect(Language.difference(x.language, y.language) == ["a", "b"])
    }

    @Test func optionalSuffixIsFactored() {
        // X | X Y  ->  X [ Y ]
        let x = GrammarExpression.makeChoice([sym("x"), .sequence([sym("x"), sym("y")])])
        #expect(x?.ebnf == "x [ y ]")
    }

    @Test func commonPrefixIsFactored() {
        let x = GrammarExpression.makeChoice([.sequence([sym("A"), sym("B")]), .sequence([sym("A"), sym("C")])])
        #expect(x?.ebnf == "'A' ( 'B' | 'C' )")
    }

    @Test func repetitionIsRotatedToLeadWithItsElement() {
        // { a , } a  ->  a { , a }
        let x = GrammarExpression.makeSequence([.repetition(.sequence([sym("a"), sym(",")])), sym("a")])
        #expect(x?.ebnf == "a { ',' a }")
    }

    @Test func redundantAlternativesAreRemoved() {
        let reference = GrammarExpression.sequence([sym("a"), .choice([.empty, sym("b")])]).language
        let verbose = GrammarExpression.choice([sym("a"), .sequence([sym("a"), .choice([.empty, sym("b")])])])
        #expect(verbose.removingRedundantAlternatives(matching: reference).ebnf == "a [ b ]")
    }

    @Test func pruningKeepsLanguage() {
        let expression = GrammarExpression.sequence([sym("a"), .repetition(.choice([sym("b"), .empty]))])
        let language = expression.language
        let pruned = language.pruned()
        #expect(Language.equivalent(language, pruned))
        #expect(pruned.automaton.epsilonEdges.count <= language.automaton.epsilonEdges.count)
    }
}
