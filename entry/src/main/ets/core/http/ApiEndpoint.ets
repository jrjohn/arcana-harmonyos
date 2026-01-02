/**
 * ApiEndpoint - Declarative Endpoint Definition for HarmonyOS ArkTS
 *
 * Provides a fluent builder pattern for defining API endpoints declaratively,
 * similar to Retrofit/Ktorfit interface definitions but compatible with ArkTS.
 *
 * Usage:
 * ```
 * const getUser = Endpoint.get<User>('/users/{id}')
 *   .pathParam('id')
 *   .mapResponse((raw) => UserMapper.toDomain(raw as UserDto))
 *   .build();
 *
 * const result = await getUser.execute(client, new Map([['id', '123']]));
 * ```
 */

import { ApiClient, HttpMethod, ResponseMapper } from './ApiClient';
import { Result } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';

/**
 * Executable endpoint interface
 */
export interface ExecutableEndpoint<TResponse> {
  execute(
    client: ApiClient,
    pathParams?: Map<string, string>,
    queryParams?: Map<string, string>
  ): Promise<Result<TResponse, AppError>>;
}

/**
 * Executable endpoint with body
 */
export interface ExecutableEndpointWithBody<TBody, TResponse> {
  execute(
    client: ApiClient,
    body: TBody,
    pathParams?: Map<string, string>,
    queryParams?: Map<string, string>
  ): Promise<Result<TResponse, AppError>>;
}

/**
 * Executable void endpoint (for DELETE, etc.)
 */
export interface ExecutableVoidEndpoint {
  execute(
    client: ApiClient,
    pathParams?: Map<string, string>,
    queryParams?: Map<string, string>
  ): Promise<Result<void, AppError>>;
}

/**
 * GET endpoint implementation
 */
class GetEndpoint<TResponse> implements ExecutableEndpoint<TResponse> {
  private path: string;
  private mapper: ResponseMapper<Object, TResponse>;

  constructor(path: string, mapper: ResponseMapper<Object, TResponse>) {
    this.path = path;
    this.mapper = mapper;
  }

  async execute(
    client: ApiClient,
    pathParams: Map<string, string> = new Map(),
    queryParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    return client.get(this.path, this.mapper, queryParams, pathParams);
  }
}

/**
 * POST endpoint implementation
 */
class PostEndpoint<TBody, TResponse> implements ExecutableEndpointWithBody<TBody, TResponse> {
  private path: string;
  private mapper: ResponseMapper<Object, TResponse>;

  constructor(path: string, mapper: ResponseMapper<Object, TResponse>) {
    this.path = path;
    this.mapper = mapper;
  }

  async execute(
    client: ApiClient,
    body: TBody,
    pathParams: Map<string, string> = new Map(),
    queryParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    return client.post(this.path, body, this.mapper, queryParams, pathParams);
  }
}

/**
 * PUT endpoint implementation
 */
class PutEndpoint<TBody, TResponse> implements ExecutableEndpointWithBody<TBody, TResponse> {
  private path: string;
  private mapper: ResponseMapper<Object, TResponse>;

  constructor(path: string, mapper: ResponseMapper<Object, TResponse>) {
    this.path = path;
    this.mapper = mapper;
  }

  async execute(
    client: ApiClient,
    body: TBody,
    pathParams: Map<string, string> = new Map(),
    queryParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    return client.put(this.path, body, this.mapper, queryParams, pathParams);
  }
}

/**
 * PATCH endpoint implementation
 */
class PatchEndpoint<TBody, TResponse> implements ExecutableEndpointWithBody<TBody, TResponse> {
  private path: string;
  private mapper: ResponseMapper<Object, TResponse>;

  constructor(path: string, mapper: ResponseMapper<Object, TResponse>) {
    this.path = path;
    this.mapper = mapper;
  }

  async execute(
    client: ApiClient,
    body: TBody,
    pathParams: Map<string, string> = new Map(),
    queryParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    return client.patch(this.path, body, this.mapper, queryParams, pathParams);
  }
}

/**
 * DELETE endpoint implementation
 */
class DeleteEndpoint implements ExecutableVoidEndpoint {
  private path: string;

  constructor(path: string) {
    this.path = path;
  }

  async execute(
    client: ApiClient,
    pathParams: Map<string, string> = new Map(),
    queryParams: Map<string, string> = new Map()
  ): Promise<Result<void, AppError>> {
    return client.delete(this.path, pathParams, queryParams);
  }
}

/**
 * Builder for GET endpoints
 */
export class GetEndpointBuilder<TResponse> {
  private path: string;
  private pathParamNames: string[] = [];
  private queryParamNames: string[] = [];
  private mapper: ResponseMapper<Object, TResponse> | undefined;

  constructor(path: string) {
    this.path = path;
  }

  /**
   * Declares a path parameter (e.g., '/users/{id}')
   */
  pathParam(name: string): GetEndpointBuilder<TResponse> {
    this.pathParamNames.push(name);
    return this;
  }

  /**
   * Declares a query parameter
   */
  queryParam(name: string): GetEndpointBuilder<TResponse> {
    this.queryParamNames.push(name);
    return this;
  }

  /**
   * Sets the response mapper function
   */
  mapResponse(mapper: ResponseMapper<Object, TResponse>): GetEndpointBuilder<TResponse> {
    this.mapper = mapper;
    return this;
  }

  /**
   * Builds the executable endpoint
   */
  build(): ExecutableEndpoint<TResponse> {
    if (!this.mapper) {
      throw new Error('Response mapper is required. Call mapResponse() before build().');
    }
    return new GetEndpoint(this.path, this.mapper);
  }
}

/**
 * Builder for POST endpoints
 */
export class PostEndpointBuilder<TBody, TResponse> {
  private path: string;
  private pathParamNames: string[] = [];
  private queryParamNames: string[] = [];
  private mapper: ResponseMapper<Object, TResponse> | undefined;

  constructor(path: string) {
    this.path = path;
  }

  pathParam(name: string): PostEndpointBuilder<TBody, TResponse> {
    this.pathParamNames.push(name);
    return this;
  }

  queryParam(name: string): PostEndpointBuilder<TBody, TResponse> {
    this.queryParamNames.push(name);
    return this;
  }

  mapResponse(mapper: ResponseMapper<Object, TResponse>): PostEndpointBuilder<TBody, TResponse> {
    this.mapper = mapper;
    return this;
  }

  build(): ExecutableEndpointWithBody<TBody, TResponse> {
    if (!this.mapper) {
      throw new Error('Response mapper is required. Call mapResponse() before build().');
    }
    return new PostEndpoint(this.path, this.mapper);
  }
}

/**
 * Builder for PUT endpoints
 */
export class PutEndpointBuilder<TBody, TResponse> {
  private path: string;
  private pathParamNames: string[] = [];
  private queryParamNames: string[] = [];
  private mapper: ResponseMapper<Object, TResponse> | undefined;

  constructor(path: string) {
    this.path = path;
  }

  pathParam(name: string): PutEndpointBuilder<TBody, TResponse> {
    this.pathParamNames.push(name);
    return this;
  }

  queryParam(name: string): PutEndpointBuilder<TBody, TResponse> {
    this.queryParamNames.push(name);
    return this;
  }

  mapResponse(mapper: ResponseMapper<Object, TResponse>): PutEndpointBuilder<TBody, TResponse> {
    this.mapper = mapper;
    return this;
  }

  build(): ExecutableEndpointWithBody<TBody, TResponse> {
    if (!this.mapper) {
      throw new Error('Response mapper is required. Call mapResponse() before build().');
    }
    return new PutEndpoint(this.path, this.mapper);
  }
}

/**
 * Builder for PATCH endpoints
 */
export class PatchEndpointBuilder<TBody, TResponse> {
  private path: string;
  private pathParamNames: string[] = [];
  private queryParamNames: string[] = [];
  private mapper: ResponseMapper<Object, TResponse> | undefined;

  constructor(path: string) {
    this.path = path;
  }

  pathParam(name: string): PatchEndpointBuilder<TBody, TResponse> {
    this.pathParamNames.push(name);
    return this;
  }

  queryParam(name: string): PatchEndpointBuilder<TBody, TResponse> {
    this.queryParamNames.push(name);
    return this;
  }

  mapResponse(mapper: ResponseMapper<Object, TResponse>): PatchEndpointBuilder<TBody, TResponse> {
    this.mapper = mapper;
    return this;
  }

  build(): ExecutableEndpointWithBody<TBody, TResponse> {
    if (!this.mapper) {
      throw new Error('Response mapper is required. Call mapResponse() before build().');
    }
    return new PatchEndpoint(this.path, this.mapper);
  }
}

/**
 * Builder for DELETE endpoints
 */
export class DeleteEndpointBuilder {
  private path: string;
  private pathParamNames: string[] = [];
  private queryParamNames: string[] = [];

  constructor(path: string) {
    this.path = path;
  }

  pathParam(name: string): DeleteEndpointBuilder {
    this.pathParamNames.push(name);
    return this;
  }

  queryParam(name: string): DeleteEndpointBuilder {
    this.queryParamNames.push(name);
    return this;
  }

  build(): ExecutableVoidEndpoint {
    return new DeleteEndpoint(this.path);
  }
}

/**
 * Main Endpoint factory - entry point for declarative endpoint definition
 *
 * Usage:
 * ```
 * // Define endpoints
 * const getUsers = Endpoint.get<PaginatedUsers>('/users')
 *   .queryParam('page')
 *   .mapResponse(PaginatedUsersMapper.fromRaw)
 *   .build();
 *
 * const getUser = Endpoint.get<User>('/users/{id}')
 *   .pathParam('id')
 *   .mapResponse(UserMapper.fromRaw)
 *   .build();
 *
 * const createUser = Endpoint.post<CreateUserDto, User>('/users')
 *   .mapResponse(UserMapper.fromRaw)
 *   .build();
 *
 * const updateUser = Endpoint.put<UpdateUserDto, User>('/users/{id}')
 *   .pathParam('id')
 *   .mapResponse(UserMapper.fromRaw)
 *   .build();
 *
 * const deleteUser = Endpoint.delete('/users/{id}')
 *   .pathParam('id')
 *   .build();
 *
 * // Execute endpoints
 * const usersResult = await getUsers.execute(client, undefined, new Map([['page', '1']]));
 * const userResult = await getUser.execute(client, new Map([['id', '123']]));
 * const newUserResult = await createUser.execute(client, createDto);
 * ```
 */
export class Endpoint {
  /**
   * Creates a GET endpoint builder
   */
  static get<TResponse>(path: string): GetEndpointBuilder<TResponse> {
    return new GetEndpointBuilder<TResponse>(path);
  }

  /**
   * Creates a POST endpoint builder
   */
  static post<TBody, TResponse>(path: string): PostEndpointBuilder<TBody, TResponse> {
    return new PostEndpointBuilder<TBody, TResponse>(path);
  }

  /**
   * Creates a PUT endpoint builder
   */
  static put<TBody, TResponse>(path: string): PutEndpointBuilder<TBody, TResponse> {
    return new PutEndpointBuilder<TBody, TResponse>(path);
  }

  /**
   * Creates a PATCH endpoint builder
   */
  static patch<TBody, TResponse>(path: string): PatchEndpointBuilder<TBody, TResponse> {
    return new PatchEndpointBuilder<TBody, TResponse>(path);
  }

  /**
   * Creates a DELETE endpoint builder
   */
  static delete(path: string): DeleteEndpointBuilder {
    return new DeleteEndpointBuilder(path);
  }
}
