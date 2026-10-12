@_exported import CalcC
import Foundation

// Interface-only declarations of the private Calculate.framework.
// Bodies never run: the oracle links against the real framework, and the
// mangled names of these declarations match its exports.
public class CalculateExpression {
  public enum Base: Int { case base8, base10, base16 }
  public init(_ expression: String, options: [CalculateKey: Any], base: Base, id: UUID) { fatalError() }
  public final func update(_ op: Operation) -> Bool { fatalError() }
  public final var format: CalculateFormat { get { fatalError() } set { fatalError() } }
  public final var assumeDegrees: Bool { get { fatalError() } set { fatalError() } }
  public final var postfixStack: [CalculateExpression] { fatalError() }
  public final var expression: String { fatalError() }
  public final var result: CalculateResult? { fatalError() }
  public final var numberFormatter: NumberFormatter? { get { fatalError() } set { fatalError() } }
  public final var plain: PlainExpression { fatalError() }
  public class PlainExpression { public var text: String { fatalError() } }
  public class Operation {
    public static var add: BasicOperatorOperation { fatalError() }
    public static var allClear: AllClearOperation { fatalError() }
    public static var and: BasicOperatorOperation { fatalError() }
    public static var byteFlip: FlipOperation { fatalError() }
    public static var clear: ClearOperation { fatalError() }
    public static var closeParenthesis: CloseParenthesisOperation { fatalError() }
    public static var cosine: FunctionOperation { fatalError() }
    public static var cube: PowerOperation { fatalError() }
    public static var cubeRoot: RootOperation { fatalError() }
    public static var decimal: LiteralOperation { fatalError() }
    public static var delete: DeleteOperation { fatalError() }
    public static var digit0: LiteralOperation { fatalError() }
    public static var digit00: LiteralOperation { fatalError() }
    public static var digit1: LiteralOperation { fatalError() }
    public static var digit2: LiteralOperation { fatalError() }
    public static var digit3: LiteralOperation { fatalError() }
    public static var digit4: LiteralOperation { fatalError() }
    public static var digit5: LiteralOperation { fatalError() }
    public static var digit6: LiteralOperation { fatalError() }
    public static var digit7: LiteralOperation { fatalError() }
    public static var digit8: LiteralOperation { fatalError() }
    public static var digit9: LiteralOperation { fatalError() }
    public static var digitA: LiteralOperation { fatalError() }
    public static var digitB: LiteralOperation { fatalError() }
    public static var digitC: LiteralOperation { fatalError() }
    public static var digitD: LiteralOperation { fatalError() }
    public static var digitE: LiteralOperation { fatalError() }
    public static var digitF: LiteralOperation { fatalError() }
    public static var digitFF: LiteralOperation { fatalError() }
    public static var divide: BasicOperatorOperation { fatalError() }
    public static var drop: DropOperation { fatalError() }
    public static var ee: LiteralOperation { fatalError() }
    public static var enter: EnterOperation { fatalError() }
    public static var equals: EqualsOperation { fatalError() }
    public static var eulerNumber: ConstantOperation { fatalError() }
    public static var exponentialBase10: ExponentialOperation { fatalError() }
    public static var exponentialBase2: ExponentialOperation { fatalError() }
    public static var exponentialBaseCustom: ExponentialOperation { fatalError() }
    public static var exponentialBaseEuler: ExponentialOperation { fatalError() }
    public static var factorial: FactorialOperation { fatalError() }
    public static var hyperbolicCosine: FunctionOperation { fatalError() }
    public static var hyperbolicSine: FunctionOperation { fatalError() }
    public static var hyperbolicTangent: FunctionOperation { fatalError() }
    public static var inverseCosine: FunctionOperation { fatalError() }
    public static var inverseHyperbolicCosine: FunctionOperation { fatalError() }
    public static var inverseHyperbolicSine: FunctionOperation { fatalError() }
    public static var inverseHyperbolicTangent: FunctionOperation { fatalError() }
    public static var inverseSine: FunctionOperation { fatalError() }
    public static var inverseTangent: FunctionOperation { fatalError() }
    public static var leftRotate: ShiftOperation { fatalError() }
    public static var leftRotateCustom: ShiftOperation { fatalError() }
    public static var leftShift: ShiftOperation { fatalError() }
    public static var leftShiftCustom: ShiftOperation { fatalError() }
    public static var logarithmBase10: LogOperation { fatalError() }
    public static var logarithmBase2: LogOperation { fatalError() }
    public static var logarithmBaseCustom: LogOperation { fatalError() }
    public static var logarithmNatural: FunctionOperation { fatalError() }
    public static var mod: BasicOperatorOperation { fatalError() }
    public static var multiply: BasicOperatorOperation { fatalError() }
    public static var neg: NegOperation { fatalError() }
    public static var negate: NegateOperation { fatalError() }
    public static var nor: BasicOperatorOperation { fatalError() }
    public static var not: NotOperation { fatalError() }
    public static var onesComplement: NotOperation { fatalError() }
    public static var openParenthesis: OpenParenthesisOperation { fatalError() }
    public static var or: BasicOperatorOperation { fatalError() }
    public static var percent: BasicOperatorOperation { fatalError() }
    public static var pi: ConstantOperation { fatalError() }
    public static var power: PowerOperation { fatalError() }
    public static var random: RandOperation { fatalError() }
    public static var reciprocal: ReciprocalOperation { fatalError() }
    public static var reverseRoot: RootOperation { fatalError() }
    public static var rightRotate: ShiftOperation { fatalError() }
    public static var rightRotateCustom: ShiftOperation { fatalError() }
    public static var rightShift: ShiftOperation { fatalError() }
    public static var rightShiftCustom: ShiftOperation { fatalError() }
    public static var rollIn: RollInOperation { fatalError() }
    public static var rollOut: RollOutOperation { fatalError() }
    public static var root: RootOperation { fatalError() }
    public static var sine: FunctionOperation { fatalError() }
    public static var square: PowerOperation { fatalError() }
    public static var squareRoot: RootOperation { fatalError() }
    public static var subtract: BasicOperatorOperation { fatalError() }
    public static var swap: SwapOperation { fatalError() }
    public static var tangent: FunctionOperation { fatalError() }
    public static var twosComplement: NegOperation { fatalError() }
    public static var wordFlip: FlipOperation { fatalError() }
    public static var xor: BasicOperatorOperation { fatalError() }
  }
  public class AllClearOperation: Operation {}
  public class BasicOperatorOperation: Operation {}
  public class ClearOperation: Operation {}
  public class CloseParenthesisOperation: Operation {}
  public class ConstantOperation: Operation {}
  public class DeleteOperation: Operation {}
  public class DropOperation: Operation {}
  public class EnterOperation: Operation {}
  public class EqualsOperation: Operation {}
  public class ExponentialOperation: Operation {}
  public class FactorialOperation: Operation {}
  public class FlipOperation: Operation {}
  public class FunctionOperation: Operation {}
  public class LiteralOperation: Operation {}
  public class LogOperation: Operation {}
  public class NegOperation: Operation {}
  public class NegateOperation: Operation {}
  public class NotOperation: Operation {}
  public class OpenParenthesisOperation: Operation {}
  public class PowerOperation: Operation {}
  public class RandOperation: Operation {}
  public class ReciprocalOperation: Operation {}
  public class RollInOperation: Operation {}
  public class RollOutOperation: Operation {}
  public class RootOperation: Operation {}
  public class ShiftOperation: Operation {}
  public class SwapOperation: Operation {}
}
