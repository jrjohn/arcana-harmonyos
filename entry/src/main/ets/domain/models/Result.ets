/**
 * Represents the result of an operation that can either succeed or fail.
 * This is a discriminated union type for type-safe error handling.
 */

/**
 * Represents a successful result containing a value
 */
export class Success<T> {
  readonly kind: string = 'success';
  readonly value: T;
  readonly isSuccess: boolean = true;
  readonly isFailure: boolean = false;

  constructor(value: T) {
    this.value = value;
  }
}

/**
 * Represents a failed result containing an error
 */
export class Failure<E> {
  readonly kind: string = 'failure';
  readonly error: E;
  readonly isSuccess: boolean = false;
  readonly isFailure: boolean = true;

  constructor(error: E) {
    this.error = error;
  }
}

/**
 * Result type union
 */
export type Result<T, E = Error> = Success<T> | Failure<E>;

/**
 * Factory and utility class for Result type
 */
export class ResultFactory {
  /**
   * Creates a successful result
   */
  static success<T>(value: T): Success<T> {
    return new Success<T>(value);
  }

  /**
   * Creates a failed result
   */
  static failure<E>(error: E): Failure<E> {
    return new Failure<E>(error);
  }

  /**
   * Maps the success value to a new value
   */
  static map<T, U, E>(result: Result<T, E>, fn: (value: T) => U): Result<U, E> {
    if (result.isSuccess) {
      const successResult = result as Success<T>;
      return ResultFactory.success(fn(successResult.value));
    }
    return result as Failure<E>;
  }

  /**
   * Maps the error to a new error type
   */
  static mapError<T, E, F>(result: Result<T, E>, fn: (error: E) => F): Result<T, F> {
    if (result.isFailure) {
      const failureResult = result as Failure<E>;
      return ResultFactory.failure(fn(failureResult.error));
    }
    return result as Success<T>;
  }

  /**
   * Flat maps the success value
   */
  static flatMap<T, U, E>(result: Result<T, E>, fn: (value: T) => Result<U, E>): Result<U, E> {
    if (result.isSuccess) {
      const successResult = result as Success<T>;
      return fn(successResult.value);
    }
    return result as Failure<E>;
  }

  /**
   * Gets the value or returns a default
   */
  static getOrElse<T, E>(result: Result<T, E>, defaultValue: T): T {
    if (result.isSuccess) {
      const successResult = result as Success<T>;
      return successResult.value;
    }
    return defaultValue;
  }

  /**
   * Gets the value or throws the error
   */
  static getOrThrow<T, E>(result: Result<T, E>): T {
    if (result.isSuccess) {
      const successResult = result as Success<T>;
      return successResult.value;
    }
    const failureResult = result as Failure<E>;
    const error = failureResult.error;
    if (error instanceof Error) {
      const errorInstance = error as Error;
      throw errorInstance;
    }
    throw new Error(String(error));
  }

  /**
   * Folds the result into a single value
   */
  static fold<T, E, R>(
    result: Result<T, E>,
    onSuccess: (value: T) => R,
    onFailure: (error: E) => R
  ): R {
    if (result.isSuccess) {
      const successResult = result as Success<T>;
      return onSuccess(successResult.value);
    }
    const failureResult = result as Failure<E>;
    return onFailure(failureResult.error);
  }

  /**
   * Wraps a promise into a Result
   */
  static async fromPromise<T>(promise: Promise<T>): Promise<Result<T, Error>> {
    try {
      const value = await promise;
      return ResultFactory.success(value);
    } catch (error) {
      if (error instanceof Error) {
        return ResultFactory.failure(error);
      }
      return ResultFactory.failure(new Error(String(error)));
    }
  }

  /**
   * Wraps a throwing function into a Result
   */
  static fromTry<T>(fn: () => T): Result<T, Error> {
    try {
      return ResultFactory.success(fn());
    } catch (error) {
      if (error instanceof Error) {
        return ResultFactory.failure(error);
      }
      return ResultFactory.failure(new Error(String(error)));
    }
  }

  /**
   * Combines multiple results into a single result
   */
  static combine<T, E>(results: Result<T, E>[]): Result<T[], E> {
    const values: T[] = [];
    for (const result of results) {
      if (result.isFailure) {
        return result as Failure<E>;
      }
      const successResult = result as Success<T>;
      values.push(successResult.value);
    }
    return ResultFactory.success(values);
  }
}
