//  Copyright © 2019 The nef Authors.

import Common
import Bow
import BowEffects

typealias EnvIO<D, E: Error, A> = Kleisli<IOPartial<E>, D, A>
typealias EnvIOPartial<D, E: Error> = KleisliPartial<IOPartial<E>, D>

extension IO {
    static func invokeEither(_ f: @escaping () -> Either<E, A>) -> IO<E, A> {
        return IO<E, Either<E, A>>.invoke(f).flatMap { either in
            either.fold(IO.raiseError, IO.pure)
        }^
    }
}

extension Kleisli {
    func mapError<E: Error, EE: Error>(_ f: @escaping (E) -> EE) -> EnvIO<D, EE, A> where F == IOPartial<E> {
        return EnvIO { env in self.invoke(env)^.mapLeft(f) }
    }
    
    func contramap<DD>(_ f: @escaping (DD) -> D) -> Kleisli<F, DD, A> {
        return Kleisli<F, DD, A> { env in self.invoke(f(env)) }
    }
    
    func contramap<DD>(_ keypath: KeyPath<DD, D>) -> Kleisli<F, DD, A> {
        return Kleisli<F, DD, A> { env in self.invoke(env[keyPath: keypath]) }
    }
    
    func handleErrorWith<E: Error>(_ f: @escaping (E) -> EnvIO<D, E, A>) -> EnvIO<D, E, A> where F == IOPartial<E> {
        return Kleisli { env in self.invoke(env).handleErrorWith { e in f(e).invoke(env) } }
    }
}

struct IPadApp {
    let console: iPadConsole
    let storage: Storage
}

extension Kind where F: Selective, A == Bool {
    func ifS<B>(_ ftrue: Kind<F, B>, else ffalse: Kind<F, B>) -> Kind<F, B> {
        return F.ifS(self, ftrue, ffalse)
    }
}

extension IO {
    func performIO() throws -> Either<E, A> {
        do {
            return .right(try self.unsafePerformIO())
        } catch let e as E {
            return .left(e)
        } catch {
            throw error
        }
    }
}
